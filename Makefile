.PHONY: all test travis-test coverage dist upload clean doc

python_bin ?= python
pretty ?= all

all:
	@echo "Usage: make deps|meta-test|test|quick-test|dist|upload|doc|clean"
	@echo " - deps: install the dependencies for byexample"
	@echo " - test: run the all the tests and validate the byexample's output."
	@echo " - travis-test: run the all the tests (tweaked for Travis CI)."
	@echo " - coverage: run the all the tests under differnet envs to measure the coverage."
	@echo " - dist: make a source and a binary distribution (package)"
	@echo " - upload: upload the source and the binary distribution to pypi"
	@echo " - deprecated-doc: (deprecated) build a pdf file from the documentation"
	@echo " - clean: restore the environment"
	@exit 1

deps:
	pip install -e .

test:
	@$(python_bin) r.py --timeout 60 --pretty $(pretty) --ff -l shell test/test.rst

travis-test:
	@# run the test separately so we can control which languages will
	@# be used. In a Travis CI environment,  Ruby, GDB and C++ are
	@# not supported
	@$(python_bin) r.py --pretty $(pretty) --ff -l python byexample/*.py
	@$(python_bin) r.py --pretty $(pretty) --ff -l python,shell byexample/modules/*.py
	@$(python_bin) r.py --pretty $(pretty) --ff -l python,shell README.md
	@$(python_bin) r.py --pretty $(pretty) --ff -l python,shell `find docs -name "*.rst"`

coverage:
	@rm -f .coverage
	@# Run the byexample's tests with the Python interpreter.
	@# to start the coverage, use a hook in test/ to initialize the coverage
	@# engine at the begin of the execution (and to finalize it at the end)
	@$(python_bin) r.py --modules test/ -q --ff -l python byexample/*.py
	@#
	@# Run the rest of the tests with an environment variable to make
	@# r.py to initialize the coverage too
	@BYEXAMPLE_COVERAGE_TEST=1 $(python_bin) r.py -q --ff -l python,shell,ruby,gdb,cpp `find docs -name "*.rst"`
	@BYEXAMPLE_COVERAGE_TEST=1 $(python_bin) r.py -q --ff -l python,shell,ruby,gdb,cpp README.md
	@#
	@# Run the another test, again, but with different flags to force the
	@# execution of different parts of byexample
	@BYEXAMPLE_COVERAGE_TEST=1 $(python_bin) r.py -vvv --ff --no-enhance-diff -l python README.md > /dev/null
	@BYEXAMPLE_COVERAGE_TEST=1 $(python_bin) r.py --pretty none -vvv --ff -l python README.md > /dev/null
	@#
	@# Output the result
	@coverage report

dist:
	rm -Rf dist/ build/ *.egg-info
	$(python_bin) setup.py sdist bdist_wheel --universal
	rm -Rf build/ *.egg-info

upload: dist
	twine upload dist/*.tar.gz dist/*.whl

deprecated-doc:
	pandoc -s -o doc.pdf README.md docs/languages/* docs/how_to_extend.rst

clean:
	rm -Rf dist/ build/ *.egg-info
	rm -Rf build/ *.egg-info
	find . -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	rm -f doc.pdf
	rm -f README.rst
