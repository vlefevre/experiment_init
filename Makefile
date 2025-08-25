CC=nvcc
CC_FLAGS=-arch=sm_80
dt=float
SRC=main.cu

all: initArray initArrayUnroll4 initArrayManualUnroll4 initArrayVec4

initArray: $(SRC)
	$(CC) -o test_$@ -DKERNEL_NAME=$@ -DDATATYPE=$(dt) $(CC_FLAGS) $(SRC)

initArrayUnroll4: $(SRC)
	$(CC) -o test_$@ -DKERNEL_NAME=$@ -DDATATYPE=$(dt) $(CC_FLAGS) $(SRC)

initArrayManualUnroll4: $(SRC)
	$(CC) -o test_$@ -DKERNEL_NAME=$@ -DDATATYPE=$(dt) $(CC_FLAGS) $(SRC)

initArrayVec4: $(SRC)
	$(CC) -o test_$@ -DKERNEL_NAME=$@ -DDATATYPE=$(dt) $(CC_FLAGS) $(SRC)

