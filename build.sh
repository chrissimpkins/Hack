#!/bin/bash

# /////////////////////////////////////////////////////////////////
#
# build.sh
#  A shell script that builds the Hack fonts from UFO source
#  Copyright 2017 Christopher Simpkins
#  MIT License
#
#  Usage: ./build.sh (--install-dependencies)
#     Arguments:
#     --install-dependencies (optional) - installs all
#       build dependencies prior to the build script execution
#
# /////////////////////////////////////////////////////////////////

# test for number of arguments
if [ $# -gt 1 ]
	then
	    echo "Inappropriate arguments included in your command." 1>&2
	    echo "Usage: ./build.sh (--install-dependencies)" 1>&2
	    exit 1
fi

if [ "$1" = "--install-dependencies" ]
	then
		# fontmake
		pip install --upgrade fontmake
		# fontTools (installed with fontmake at this time. leave this as dependency check as python scripts for fixes require it should fontTools eliminate dep)
		pip install --upgrade fonttools
		# ttfautohint v1.6 (must be pinned to v1.6 and above for Hack instruction sets)
        # begin with OS X check for platform specific ttfautohint install using Homebrew, install from source on other platforms
        platformstr=$(uname)
        if [ "$platformstr" = "Darwin" ]; then
            # test for homebrew install
            if ! which homebrew
                then
                    echo "Please manually install Homebrew (https://brew.sh/) before the execution of this script with the --install-dependencies flag on the OS X platform." 1>&2
                    exit 1
            fi

            # install Homebrew release of ttfautohint (this installs all dependencies necessary for build)
            #    use --upgrade flag to confirm latest version installed as need 1.6+
            if ! brew install --upgrade ttfautohint
                then
                    echo "Unable to install ttfautohint with Homebrew.  Please attempt to install this dependency manually and repeat this script without the --install-dependencies flag." 1>&2
                    exit 1
            fi
        else
        	# install Harfbuzz ttfautohint dependency (>v0.9.19)
            curl -L https://www.freedesktop.org/software/harfbuzz/release/harfbuzz-1.4.8.tar.bz2
            tar -xvjf harfbuzz-1.4.8.tar.bz2
            harfbuzz-1.4.8/configure
            harfbuzz-1.4.8/make
            if ! sudo harfbuzz-1.4.8/make install; then
            	echo "Unable to install ttfautohint dependency Harbuzz from source.  Please install dependencies manually and repeat this script without the --install-dependencies flag" 1>&2
            	exit 1
            fi

            curl -L https://sourceforge.net/projects/freetype/files/ttfautohint/1.6/ttfautohint-1.6.tar.gz/download -o ttfautohint.tar.gz
            tar -xvzf ttfautohint.tar.gz
            ttfautohint-1.6/configure --with-qt=no
            ttfautohint-1.6/make
            if ! sudo ttfautohint-1.6/make install; then
            	echo "Unable to install ttfautohint from source.  Please attempt to manually install this dependency and repeat this script without the --install-dependencies flag" 1>&2
            	exit 1
            fi

            if [ -f "ttfautohint-1.6.tar.gz" ]
                then
                    rm ttfautohint-1.6.tar.gz
            fi

            if [ -d "ttfautohint-1.6" ]
                then
                    rm -rf ttfautohint-1.6
            fi
        fi

		# confirm installs
		installflag=0
        # fontmake installed
		if ! which fontmake
			then
			    echo "Unable to install fontmake with 'pip install fontmake'.  Please attempt manual install and repeat build without the --install-dependencies flag." 1>&2
			    installflag=1
		fi
        # fontTools python library can be imported
		if ! python -c "import fontTools"
			then
			    echo "Unable to install fontTools with 'pip install fonttools'.  Please attempt manual install and repeat build without the --install-dependencies flag." 1>&2
			    installflag=1
		fi
        # ttfautohint installed
		if ! which ttfautohint
			then
			    echo "Unable to install ttfautohint from source.  Please attempt manual install and repeat build without the --install-dependencies flag." 1>&2
			    installflag=1
		fi
		# if any of the dependency installs failed, exit and do not attempt build, notify user
		if [ $installflag -eq 1 ]
			then
			    echo "Build canceled." 1>&2
			    exit 1
        fi
fi

# Desktop ttf font build

echo "Starting build..."
echo " "

# remove any existing release files from the build directory
if [ -f "build/ttf/Hack-Regular.ttf" ]; then
	rm build/ttf/Hack-Regular.ttf
fi

if [ -f "build/ttf/Hack-Italic.ttf" ]; then
	rm build/ttf/Hack-Italic.ttf
fi

if [ -f "build/ttf/Hack-Bold.ttf" ]; then
	rm build/ttf/Hack-Bold.ttf
fi

if [ -f "build/ttf/Hack-BoldItalic.ttf" ]; then
	rm build/ttf/Hack-BoldItalic.ttf
fi

# remove master_ttf directory if a previous build failed + exited early and it was not cleaned up

if [ -d "master_ttf" ]; then
	rm -rf master_ttf
fi

# build regular set

if ! fontmake -u "source/Hack-Regular.ufo" -o ttf
	then
	    echo "Unable to build the Hack-Regular variant set.  Build canceled." 1>&2
	    exit 1
fi

# build bold set
if ! fontmake -u "source/Hack-Bold.ufo" -o ttf
	then
	    echo "Unable to build the Hack-Bold variant set.  Build canceled." 1>&2
	    exit 1
fi

# build italic set
if ! fontmake -u "source/Hack-Italic.ufo" -o ttf
	then
	    echo "Unable to build the Hack-Italic variant set.  Build canceled." 1>&2
	    exit 1
fi

# build bold italic set

if ! fontmake -u "source/Hack-BoldItalic.ufo" -o ttf
	then
	    echo "Unable to build the Hack-BoldItalic variant set.  Build canceled." 1>&2
	    exit 1
fi

# Desktop ttf font post build fixes

# DSIG table fix with adapted fontbakery Python script
echo " "
echo "Attempting DSIG table fixes with fontbakery..."
echo " "
if ! python postbuild_processing/fixes/fix-dsig.py master_ttf/*.ttf
	then
	    echo "Unable to complete DSIG table fixes on the release files"
	    exit 1
fi

# fstype value fix with adapted fontbakery Python script
echo " "
echo "Attempting fstype fixes with fontbakery..."
echo " "
if ! python postbuild_processing/fixes/fix-fstype.py master_ttf/*.ttf
	then
	    echo "Unable to complete fstype fixes on the release files"
	    exit 1
fi

# Desktop ttf font hinting

echo " "
echo "Attempting ttfautohint hinting..."
echo " "
# make a temporary directory for the hinted files
mkdir master_ttf/hinted

# Hack-Regular.ttf
if ! ttfautohint -l 6 -r 50 -x 10 -H 181 -D latn -f latn -w G -W -t -X "" -I -R "master_ttf/Hack-Regular.ttf" -m "postbuild_processing/tt-hinting/Hack-Regular-TA.txt" "master_ttf/Hack-Regular.ttf" "master_ttf/hinted/Hack-Regular.ttf"
	then
	    echo "Unable to execute ttfautohint on the Hack-Regular variant set.  Build canceled." 1>&2
	    exit 1
fi
echo "master_ttf/Hack-Regular.ttf - successful hinting with ttfautohint"

# Hack-Bold.ttf
if ! ttfautohint -l 6 -r 50 -x 10 -H 260 -D latn -f latn -w G -W -t -X "" -I -R "master_ttf/Hack-Regular.ttf" -m "postbuild_processing/tt-hinting/Hack-Bold-TA.txt" "master_ttf/Hack-Bold.ttf" "master_ttf/hinted/Hack-Bold.ttf"
	then
	    echo "Unable to execute ttfautohint on the Hack-Bold variant set.  Build canceled." 1>&2
	    exit 1
fi
echo "master_ttf/Hack-Bold.ttf - successful hinting with ttfautohint"

# Hack-Italic.ttf
if ! ttfautohint -l 6 -r 50 -x 10 -H 145 -D latn -f latn -w G -W -t -X "" -I -R "master_ttf/Hack-Regular.ttf" -m "postbuild_processing/tt-hinting/Hack-Italic-TA.txt" "master_ttf/Hack-Italic.ttf" "master_ttf/hinted/Hack-Italic.ttf"
	then
	    echo "Unable to execute ttfautohint on the Hack-Italic variant set.  Build canceled." 1>&2
	    exit 1
fi
echo "master_ttf/Hack-Italic.ttf - successful hinting with ttfautohint"

# Hack-BoldItalic.ttf
if ! ttfautohint -l 6 -r 50 -x 10 -H 265 -D latn -f latn -w G -W -t -X "" -I -R "master_ttf/Hack-Regular.ttf" -m "postbuild_processing/tt-hinting/Hack-BoldItalic-TA.txt" "master_ttf/Hack-BoldItalic.ttf" "master_ttf/hinted/Hack-BoldItalic.ttf"
	then
	    echo "Unable to execute ttfautohint on the Hack-BoldItalic variant set.  Build canceled." 1>&2
	    exit 1
fi
echo "master_ttf/Hack-BoldItalic.ttf - successful hinting with ttfautohint"
echo " "

# Move release files to build directory
echo " "
mv master_ttf/hinted/Hack-Regular.ttf build/ttf/Hack-Regular.ttf
echo "master_ttf/Hack-Regular.ttf was moved to build/ttf/Hack-Regular.ttf"
mv master_ttf/hinted/Hack-Italic.ttf build/ttf/Hack-Italic.ttf
echo "master_ttf/Hack-Italic.ttf was moved to build/ttf/Hack-Italic.ttf"
mv master_ttf/hinted/Hack-Bold.ttf build/ttf/Hack-Bold.ttf
echo "master_ttf/Hack-Bold.ttf was moved to build/ttf/Hack-Bold.ttf"
mv master_ttf/hinted/Hack-BoldItalic.ttf build/ttf/Hack-BoldItalic.ttf
echo "master_ttf/Hack-BoldItalic.ttf was moved to build/ttf/Hack-BoldItalic.ttf"

# Remove master_ttf directory
rm -rf master_ttf
echo " "
echo "Build complete.  Release files are available in the build directory."