all: main.exe plugin.cmxs main.byte plugin.cma

parent.cmx: parent.ml
	../ocamlopt.opt -I ../stdlib -opaque -c parent.ml

parent.cmo: parent.ml
	../ocamlc.opt -I ../stdlib -c parent.ml

plugin.cmxs: module.ml parent.cmx
	../ocamlopt.opt -I ../stdlib -I . -opaque -shared -o plugin.cmxs module.ml

plugin.cma: module.ml parent.cmo
	../ocamlc.opt -I ../stdlib -I . -a -o plugin.cma module.ml

main.exe: parent.cmx main.ml
	../ocamlopt.opt -I ../stdlib -I ../otherlibs/dynlink -opaque dynlink.cmxa parent.cmx main.ml -o main.exe

main.byte: parent.cmo main.ml
	../ocamlc.opt -I ../stdlib -I ../otherlibs/dynlink -I ../runtime -custom dynlink.cma parent.cmo main.ml -o main.byte

clean:
	rm -f *.cmi *.cmx *.cmo *.o main.exe plugin.cmxs main.byte plugin.cma

.PHONY: all clean