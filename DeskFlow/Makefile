# Builds DeskFlow.app with the Command Line Tools; Xcode is not required.
APP := build/DeskFlow.app
BUNDLE_ID := com.deskflow.app
MIN_MACOS := 14.0
SOURCES := $(shell fd -e swift . DeskFlow)
ICONS := DeskFlow/Assets.xcassets/AppIcon.appiconset
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: all install clean

all: $(APP)

$(APP): $(SOURCES) DeskFlow/Info.plist $(wildcard $(ICONS)/*.png)
	rm -rf $@ build/AppIcon.iconset
	mkdir -p $@/Contents/MacOS $@/Contents/Resources build/AppIcon.iconset
	swiftc -O -parse-as-library -target arm64-apple-macos$(MIN_MACOS) $(SOURCES) -o $@/Contents/MacOS/DeskFlow
	# Info.plist keeps the Xcode placeholders; resolve them for this bundle
	cp DeskFlow/Info.plist $@/Contents/Info.plist
	plutil -replace CFBundleDevelopmentRegion -string en $@/Contents/Info.plist
	plutil -replace CFBundleExecutable -string DeskFlow $@/Contents/Info.plist
	plutil -replace CFBundleIdentifier -string $(BUNDLE_ID) $@/Contents/Info.plist
	plutil -replace CFBundleName -string DeskFlow $@/Contents/Info.plist
	plutil -replace CFBundlePackageType -string APPL $@/Contents/Info.plist
	plutil -replace LSMinimumSystemVersion -string $(MIN_MACOS) $@/Contents/Info.plist
	plutil -replace CFBundleIconFile -string AppIcon $@/Contents/Info.plist
	plutil -replace LSApplicationCategoryType -string public.app-category.utilities $@/Contents/Info.plist
	cp $(ICONS)/icon_16.png build/AppIcon.iconset/icon_16x16.png
	cp $(ICONS)/icon_32.png build/AppIcon.iconset/icon_16x16@2x.png
	cp $(ICONS)/icon_32.png build/AppIcon.iconset/icon_32x32.png
	cp $(ICONS)/icon_64.png build/AppIcon.iconset/icon_32x32@2x.png
	cp $(ICONS)/icon_128.png build/AppIcon.iconset/icon_128x128.png
	cp $(ICONS)/icon_256.png build/AppIcon.iconset/icon_128x128@2x.png
	cp $(ICONS)/icon_256.png build/AppIcon.iconset/icon_256x256.png
	cp $(ICONS)/icon_512.png build/AppIcon.iconset/icon_256x256@2x.png
	cp $(ICONS)/icon_512.png build/AppIcon.iconset/icon_512x512.png
	cp $(ICONS)/icon_1024.png build/AppIcon.iconset/icon_512x512@2x.png
	iconutil -c icns build/AppIcon.iconset -o $@/Contents/Resources/AppIcon.icns
	codesign --force --sign - $@

# ~/Applications lets the SketchyBar popup open the app with `open -b $(BUNDLE_ID)`
install: $(APP)
	rm -rf $(HOME)/Applications/DeskFlow.app
	mkdir -p $(HOME)/Applications
	cp -R $(APP) $(HOME)/Applications/
	$(LSREGISTER) -f $(HOME)/Applications/DeskFlow.app

clean:
	rm -rf build
