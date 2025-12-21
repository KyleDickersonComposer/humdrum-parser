package parsing

NOTE_NAMES :: []rune{'A', 'B', 'C', 'D', 'E', 'F', 'G', 'a', 'b', 'c', 'd', 'e', 'f', 'g'}

DURATION_NUMBERS :: []int{1, 2, 3, 4, 5, 6, 7, 8, 9}

LOWER_CASE_NOTE_NAMES :: []rune{'a', 'b', 'c', 'd', 'e', 'f', 'g'}

ACCIDENTAL :: []string{"#", "##", "-", "--", "n"}

ACCIDENTAL_RUNE :: []rune{'#', '-', 'n'}

C_SCALE :: [7]string{"C", "D", "E", "F", "G", "A", "B"}
D_SCALE :: [7]string{"D", "E", "F#", "G", "A", "B", "C#"}
E_SCALE :: [7]string{"E", "F#", "G#", "A", "B", "C#", "D#"}
F_SCALE :: [7]string{"F", "G", "A", "Bb", "C", "D", "E"}
G_SCALE :: [7]string{"G", "A", "B", "C", "D", "E", "F#"}
A_SCALE :: [7]string{"A", "B", "C#", "D", "E", "F#", "G#"}
B_SCALE :: [7]string{"B", "C#", "D#", "E", "F#", "G#", "A#"}
C_SHARP_SCALE :: [7]string{"C#", "D#", "E#", "F#", "G#", "A#", "B#"}
F_SHARP_SCALE :: [7]string{"F#", "G#", "A#", "B", "C#", "D#", "E#"}
C_FLAT_SCALE :: [7]string{"Cb", "Db", "Eb", "Fb", "Gb", "Ab", "Bb"}
D_FLAT_SCALE :: [7]string{"Db", "Eb", "F", "Gb", "Ab", "Bb", "C"}
E_FLAT_SCALE :: [7]string{"Eb", "F", "G", "Ab", "Bb", "C", "D"}
G_FLAT_SCALE :: [7]string{"Gb", "Ab", "Bb", "Cb", "Db", "Eb", "F"}
A_FLAT_SCALE :: [7]string{"Ab", "Bb", "C", "Db", "Eb", "F", "G"}
B_FLAT_SCALE :: [7]string{"Bb", "C", "D", "Eb", "F", "G", "A"}

