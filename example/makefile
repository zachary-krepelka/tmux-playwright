.PHONY: main clean

main: example.gif

clean:
	rm -f *.cast *.gif

%.gif: %.cast
	agg $< $@

.PRECIOUS: %.cast
%.cast: %.play
	bash ../playwright.sh -f $< $@
