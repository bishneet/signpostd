.PHONY: all clean install build
all: build test doc

export OCAMLRUNPARAM=b

setup.bin: setup.ml
	ocamlopt.opt -o $@ $< || ocamlopt -o $@ $< || ocamlc -o $@ $<
	rm -f setup.cmx setup.cmi setup.o setup.cmo

setup.data: setup.bin
	./setup.bin -configure

build: setup.data setup.bin
	ocamlbuild lib/server.byte
	ocamlbuild lib/client.byte

doc: setup.data setup.bin
	./setup.bin -doc

test: setup.bin build
	./setup.bin -test

clean:
	ocamlbuild -clean
	rm -f setup.data setup.log setup.bin
