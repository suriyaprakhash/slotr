.PHONY: all build dmg run clean icons

all: dmg

icons:
	bash Scripts/generate_icons.sh

build:
	bash Scripts/build_app.sh

dmg: build
	bash Scripts/package_dmg.sh

run: build
	open build/Slotr.app

clean:
	rm -rf build /tmp/Slotr* /tmp/clang-cache
