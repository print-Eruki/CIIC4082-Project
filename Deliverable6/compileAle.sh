ca65 finalDeliverable.asm
ca65 reset.asm
ld65 reset.o finalDeliverable.o -C nes.cfg -o finalDeliverable.nes
rm reset.o finalDeliverable.o
# start C:/Users/palej/Downloads/Mesen.exe
start finalDeliverable.nes