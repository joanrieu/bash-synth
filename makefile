synth: synth.cpp
	$(CXX) $(CXXFLAGS) -o $@ $^

synth.cpp: synth.sh graph $(wildcard */*.cmp)
	./synth.sh <graph >synth.cpp

.PHONY: play clean

play: synth
	./synth |aplay -f FLOAT_LE -r 44100

clean:
	rm synth.cpp
