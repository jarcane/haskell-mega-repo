.PHONY : all deps.png packdeps \
	install-ubuntu-dependencies \
	install-tools \
	install-mega-repo-tool \
	check-dirty check-checksums generate-checksums \
	doctest

CONCURRENCY?=2

HC:=ghc-8.6.3
LOCALBIN:=${HOME}/.local/bin

# Build everything
all :
	time nice cabal new-build -w $(HC) -j$(CONCURRENCY) --enable-tests all

# Install tools (from Hackage)
install-tools : $(LOCALBIN)

# Install mega-repo-tool
install-mega-repo-tool : $(LOCALBIN)
	cabal new-build -w $(HC) mega-repo-tool -j$(CONCURRENCY)
	cp `cabal-plan list-bin mega-repo-tool` $(LOCALBIN)

$(LOCALBIN) :
	mkdir -p $(LOCALBIN)

# Dependency graph
deps.png :
	cabal-plan --hide-builtin --hide-global dot --tred --tred-weights | dot -Tpng -o$@

packdeps :
	# Ignore base(-4.11) and time(-1.9)
	# Also don't fail
	packdeps -q -e base -e time */*.cabal || true

# Checks
check-dirty :
	@if [ -f cabal.project.local ]; then echo "Cannot do production build with cabal.project.local"; false; fi
	@if [ ! -z "$$(git status --porcelain)" ]; then echo "Dirty WORKINGDIR (git status)"; git status; false; fi

# Data files
check-checksums : data.sha256sums
	sha256sum -c data.sha256sums

generate-checksums :
	sha256sum $$(find -L data -type f | grep -v 'swp$$' | sort) > data.sha256sums

copy-samples :
	if [ -e data/ ]; then echo "exists!"; else ln -s data.sample data; fi

DOCTEST_OPTIONS:= --fast \
-XDeriveAnyClass \
-XDeriveFoldable \
-XDeriveFunctor \
-XDeriveGeneric \
-XDeriveTraversable \
-XDerivingStrategies \
-XGeneralizedNewtypeDeriving \
-XScopedTypeVariables \
-XStandaloneDeriving

# Doctest - ~works
doctest : doctest-fum-types doctest-futurice-logo doctest-futurice-integrations

doctest-fum-types :
	doctest $(DOCTEST_OPTIONS) fum-types/src

doctest-futurice-logo:
	doctest $(DOCTEST_OPTIONS) futurice-logo/src

doctest-futurice-integrations : 
	doctest $(DOCTEST_OPTIONS) futurice-integrations/src

# Linux
install-ubuntu-dependencies :
	apt install libfftw3-dev libpq-dev liblzma-dev zlib1g-dev g++ pkg-config apt-transport-https ca-certificates curl software-properties-common
