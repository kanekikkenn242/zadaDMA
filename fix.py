import os
import textwrap

# 1. Krijo skedarin wrapper
os.makedirs("Motor/kexploit", exist_ok=True)
wrapper_code = """#import "kfd.h"

int kexploit_run(void) {
    uint64_t kbase = kfd_init();
    if (kbase != 0) return 0;
    return -1;
}

uint64_t kexploit_kbase(void) {
    extern uint64_t kfd_kbase;
    return kfd_kbase;
}
"""
with open("Motor/kexploit/kexploit_wrapper.m", "w") as f:
    f.write(textwrap.dedent(wrapper_code))

# 2. Krijo project.yml
proj_yaml = """name: zadaDMA
options:
  bundleIdPrefix: com.apple.mobile
  deploymentTarget: { iOS: "16.0" }
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    IPHONEOS_DEPLOYMENT_TARGET: "16.0"
    CODE_SIGNING_ALLOWED: "NO"
    CODE_SIGNING_REQUIRED: "NO"
    CODE_SIGN_IDENTITY: ""
    ENABLE_BITCODE: "NO"

targets:
  zadaDMA:
    type: application
    platform: iOS
    sources:
      - path: zadaDMA
      - path: Motor
        excludes: ["zdma_crypto/**"]
      - path: Motor/kexploit/kfd/exploit
      - path: Motor/kexploit/kfd/kutils
      - path: Motor/kexploit/kfd/libkfd
      - path: Payload/zadaDMA.app
        excludes: ["Info.plist", "zadaDMA", "Assets.car"]
        buildPhase: resources
    info:
      path: Payload/zadaDMA.app/Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.apple.mobile.MobileHouseArrest
        PRODUCT_NAME: zadaDMA
        INFOPLIST_FILE: Payload/zadaDMA.app/Info.plist
        SWIFT_OBJC_BRIDGING_HEADER: Motor/MotorBridge.h
        HEADER_SEARCH_PATHS: ["$(SRCROOT)/Motor", "$(SRCROOT)/Motor/kexploit/kfd"]
        LIBRARY_SEARCH_PATHS: ["$(SRCROOT)/Motor/zdma_crypto/target/aarch64-apple-ios/release"]
        OTHER_LDFLAGS: ["-ObjC", "-lc++", "-lzdma_crypto"]
        TARGETED_DEVICE_FAMILY: "1,2"
"""
with open("project.yml", "w") as f:
    f.write(textwrap.dedent(proj_yaml))

# 3. Krijo build.yml
build_yaml = """name: build-ipa
on:
  push: { branches: [ main ] }
  workflow_dispatch:
jobs:
  build:
    runs-on: macos-14
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with: { targets: aarch64-apple-ios }
      - name: Rust staticlib
        working-directory: Motor/zdma_crypto
        run: cargo build --release --target aarch64-apple-ios
      - run: brew install xcodegen
      - run: xcodegen generate --spec project.yml
      - name: Build
        run: |
          xcodebuild -project zadaDMA.xcodeproj -scheme zadaDMA -configuration Release \\
            -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build \\
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
      - name: Force Copy Patches
        run: |
          APP=build/Build/Products/Release-iphoneos/zadaDMA.app
          if [ -f Payload/zadaDMA.app/aimdrag_neck.3105 ]; then cp Payload/zadaDMA.app/aimdrag_neck.3105 "$APP/"; fi
          if [ -f Payload/zadaDMA.app/aimneck_90.3105 ]; then cp Payload/zadaDMA.app/aimneck_90.3105 "$APP/"; fi
      - name: Package IPA
        run: |
          rm -rf pkg && mkdir -p pkg/Payload
          cp -R build/Build/Products/Release-iphoneos/zadaDMA.app pkg/Payload/
          (cd pkg && zip -ry ../zadaDMA-unsigned.ipa Payload)
      - uses: actions/upload-artifact@v4
        with:
          name: zadaDMA-ipa
          path: zadaDMA-unsigned.ipa
"""
os.makedirs(".github/workflows", exist_ok=True)
with open(".github/workflows/build.yml", "w") as f:
    f.write(textwrap.dedent(build_yaml))

print("✅ Te gjithe skedaret u krijuan me sukses!")