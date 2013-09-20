#!/bin/sh -e

DIST=`pwd`/osx_package
SANDBOX=`pwd`/.cabal-sandbox
VERSION=$(grep -e '^Version' pandoc.cabal | awk '{print $2}')
RESOURCES=$DIST/Resources
ROOT=$DIST/pandoc
SCRIPTS=osx-resources
BASE=pandoc-$VERSION
ME=jgm
CODESIGNID="Developer ID Application: John Macfarlane"
PACKAGEMAKER=/Applications/PackageMaker.app/Contents/MacOS/PackageMaker
EXES="pandoc pandoc-citeproc biblio2yaml"

echo Removing old files...
rm -rf $DIST
mkdir -p $RESOURCES

echo Updating database
cabal update

echo Building pandoc...
cabal sandbox init
cabal install --reinstall --flags="embed_data_files" pandoc-citeproc
cabal install --reinstall --flags="embed_data_files"

mkdir -p $ROOT/usr/local/bin
mkdir -p $ROOT/usr/local/share/man/man1
mkdir -p $ROOT/usr/local/share/man/man5
mkdir -p $ROOT/usr/local/opt/icu4c/lib
for f in $EXES; do
  cp $SANDBOX/bin/$f $ROOT/usr/local/bin/;
  cp $SANDBOX/share/man/man1/$f.1 $ROOT/usr/local/share/man/man1/
done
cp $SANDBOX/share/man/man5/pandoc_markdown.5 $ROOT/usr/local/share/man/man5/

chown -R $ME:staff $DIST
# gzip $ROOT/usr/local/share/man/man?/*.*
# cabal gives man pages the wrong permissions
chmod +r $ROOT/usr/local/share/man/man?/*.*

echo Copying license...
$SANDBOX/bin/pandoc --data data -t rtf -s COPYING -o $RESOURCES/License.rtf

echo Signing pandoc executable...

codesign --force --sign "$CODESIGNID" $ROOT/usr/local/bin/pandoc
# make sure it's valid... returns nonzero exit code if it isn't:
spctl --assess --type execute $ROOT/usr/local/bin/pandoc

echo Creating OSX package...

sudo $PACKAGEMAKER \
    --root $ROOT \
    --id net.johnmacfarlane.pandoc \
    --resources $RESOURCES \
    --version $VERSION \
    --scripts $SCRIPTS \
    --out $BASE.pkg

    # --no-relocate

echo Signing package...

sudo codesign --force --sign "$CODESIGNID" $BASE.pkg
# make sure it's valid...
spctl --assess --type install $BASE.pkg

echo Creating disk image...

sudo hdiutil create "$BASE.dmg" \
    -format UDZO -ov \
    -volname "pandoc $VERSION" \
    -srcfolder $BASE.pkg
sudo hdiutil internet-enable "$BASE.dmg"

