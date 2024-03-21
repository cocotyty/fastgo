// Code generated by command: go run main.go. DO NOT EDIT.

#include "textflag.h"

DATA rotate_perm<>+0(SB)/8, $0x0000000000000007
DATA rotate_perm<>+8(SB)/8, $0x0000000000000000
DATA rotate_perm<>+16(SB)/8, $0x0000000000000001
DATA rotate_perm<>+24(SB)/8, $0x0000000000000002
DATA rotate_perm<>+32(SB)/8, $0x0000000000000003
DATA rotate_perm<>+40(SB)/8, $0x0000000000000004
DATA rotate_perm<>+48(SB)/8, $0x0000000000000005
DATA rotate_perm<>+56(SB)/8, $0x0000000000000006
GLOBL rotate_perm<>(SB), RODATA, $64

// func encodeTokensArchV4(hist *histogram, tokens []token, buf *BitBuf) int
// Requires: AVX, AVX512BW, AVX512DQ, AVX512F, BMI2
TEXT ·encodeTokensArchV4(SB), NOSPLIT, $0-48
	// rotatePerm = rotate_perm
	VMOVDQU64 rotate_perm<>+0(SB), Z0

	// table = hist
	MOVQ hist+0(FP), AX
	MOVQ buf+32(FP), CX

	// output = buf.output
	MOVQ (CX), DX

	// outputEnd = output + len(buf.output) 
	MOVQ         8(CX), BX
	CMPQ         BX, $0x00000038
	JBE          skip
	ADDQ         DX, BX
	MOVQ         24(CX), SI
	ADDQ         SI, DX
	MOVQ         32(CX), SI
	MOVQ         40(CX), CX
	MOVQ         tokens_base+8(FP), DI
	MOVQ         tokens_len+16(FP), R8
	CMPQ         R8, $0x00000020
	JBE          skip
	LEAQ         (DI)(R8*4), R8
	SUBQ         $0x00000080, R8
	SUBQ         $0x00000038, BX
	KXORQ        K0, K0, K0
	MOVQ         $0x5555555555555555, R9
	KMOVQ        R9, K1
	MOVQ         $0x00000000fffffff0, R9
	KMOVQ        R9, K2
	MOVQ         $0x00000000fffffffc, R9
	KMOVQ        R9, K3
	MOVQ         $0x0101010101010101, R9
	KMOVQ        R9, K4
	MOVQ         $0x00000000fffffffe, R9
	KMOVQ        R9, K5
	MOVQ         $0x0000000000000007, R9
	VPBROADCASTQ R9, Z1
	VPTERNLOGD   $0x55, Z1, Z2, Z2

	// litMask = 0x3ff
	MOVL         $0x000003ff, R9
	VPBROADCASTD R9, Z3

	// distMask = 0x1ff
	MOVL         $0x000001ff, R9
	VPBROADCASTD R9, Z4

	// litCodeMask = 0xff_ff_ff
	MOVL         $0x00ffffff, R9
	VPBROADCASTD R9, Z5

	// extraBitCountMask = 0xff
	MOVL         $0x000000ff, R9
	VPBROADCASTD R9, Z6

	// maxShortCodeLen = (64 - 8) / 2
	MOVL         $0x0000001c, R9
	VPBROADCASTD R9, Z7
	KNOTQ        K0, K4

	// tokens = load512(tokenPtr)
	VMOVDQU64 (DI), Z8

	// symbols := tokens & LitMask
	VPANDD Z8, Z3, Z9

	// litlenHuffcodes = hufftable[symbols]
	VPGATHERDD 124(AX)(Z9*4), K4, Z10
	KNOTQ      K0, K4

	// distSymbols = (tokens >> distOffset) & distMask
	VPSRLD $0x0a, Z8, Z9
	VPANDD Z9, Z4, Z9

	// distHuffcodes = hufftable[distSymbols]
	VPGATHERDD (AX)(Z9*4), K4, Z11

	// bits = fn.bits
	VMOVQ SI, X12

	// bitsLen = fn.bitsLen
	VMOVQ CX, X13

loop:
	// litLenCodeLens = litlenHuffcodes >> 24
	// litLenCodes = litlenHuffcodes & 0xff_ff_ff
	VPSRLD $0x18, Z10, Z15
	VPANDD Z5, Z10, Z14

	// distCodes = distHuffCodes &  0xff_ff
	VMOVDQU16.Z Z11, K1, Z16

	// distCodeLens = distHuffCodes >> 24
	VPSRLD $0x18, Z11, Z17

	// extraBitCounts = (distHuffCodes >> 16) 0xff
	VPSRLD $0x10, Z11, Z18
	VPANDD Z6, Z18, Z18

	// extraBits = tokens >> 19
	VPSRLD $0x13, Z8, Z19

	// if output == outputEnd { break loop}
	CMPQ DX, BX
	JA   output_end

	// ; prepare for next iteration
	ADDQ  $0x00000040, DI
	KNOTQ K0, K4

	// tokens = load512(tokenPtr)
	VMOVDQU64 (DI), Z8

	// symbols := tokens & LitMask
	VPANDD Z8, Z3, Z9

	// litlenHuffcodes = hufftable[symbols]
	VPGATHERDD 124(AX)(Z9*4), K4, Z10
	KNOTQ      K0, K4

	// distSymbols = (tokens >> distOffset) & distMask
	VPSRLD $0x0a, Z8, Z9
	VPANDD Z9, Z4, Z9

	// distHuffcodes = hufftable[distSymbols]
	VPGATHERDD (AX)(Z9*4), K4, Z11

	// distCodes = distCodes | (extraBits << distCodeLens)
	VPSLLVD Z17, Z19, Z19
	VPORD   Z19, Z16, Z16

	// distCodeLens += extraBitCounts 
	VPADDD Z17, Z18, Z17

	// tempLens=litLenCodeLens + distCodeLens
	VPADDD Z15, Z17, Z9

	// if  tempLens > 28 { goto long_codes}
	VPCMPGTD Z7, Z9, K4
	KTESTD   K4, K4
	JNZ      long_codes

	// litLenCodes = litLenCodes | (distCodes << litLenCodeLens)
	VPSLLVD Z15, Z16, Z16
	VPORD   Z14, Z16, Z14

	// tempBits = keepEvenItems(litLenCodes) 
	VMOVDQA32.Z Z14, K1, Z16

	// litLenCodes_64 >>= 32
	VPSRLQ $0x20, Z14, Z14

	// litLenCodeLens = tempLens >> 32
	VPSRLQ $0x20, Z9, Z15

	// tempLens = keepEvenItems(tempLens)
	VMOVDQA32.Z Z9, K1, Z9

	// ; Merge tempBits and existed bits
	// tempBits = (tempBits << bitsCount) | bits
	VPSLLVQ Z13, Z16, Z16
	VPORQ   Z12, Z16, Z16

	// tempLens += bitsCount
	VPADDQ Z13, Z9, Z9

	// ; Merge tempBits and odd-indexed codes
	// litLenCodes = (litLenCodes << tempLens) | tempBits
	VPSLLVQ Z9, Z14, Z14
	VPORQ   Z14, Z16, Z14

	// litLenCodeLens += tempLens
	VPADDQ       Z15, Z9, Z15
	VPXORQ       Z20, Z20, Z20
	VPERMQ       Z15, Z0, K5, Z20
	VPADDQ       Z20, Z15, Z9
	VSHUFI64X2.Z $0x90, Z9, Z9, K3, Z20
	VPADDQ       Z20, Z9, Z9
	VSHUFI64X2.Z $0x40, Z9, Z9, K2, Z20
	VPADDQ       Z20, Z9, Z9
	VPANDQ       Z1, Z9, Z13
	VPERMQ.Z     Z13, Z0, K5, Z12
	VPSLLVQ      Z12, Z14, Z14
	VPCMPQ       $0x01, Z13, Z15, K5, K6
	VPSRLQ       $0x03, Z9, Z9
	VPADDQ       Z12, Z15, Z15
	VPANDQ       Z2, Z15, Z15
	VPSRLVQ      Z15, Z14, Z19
	KTESTD       K6, K6
	JNZ          merge_bytes

small_code_write_out:
	KNOTQ         K5, K7
	VPERMQ.Z      Z19, Z0, K7, Z12
	VPERMQ.Z      Z13, Z0, K7, Z13
	VPERMQ.Z      Z19, Z0, K5, Z19
	VPXORD        Z19, Z14, Z14
	VEXTRACTI64X2 $0x03, Z9, X15
	VPEXTRQ       $0x01, X15, CX
	KNOTQ         K0, K6
	VPERMQ.Z      Z9, Z0, K5, Z9
	VPSCATTERQQ   Z14, K6, (DX)(Z9*1)
	ADDQ          CX, DX
	CMPQ          DI, R8
	JBE           loop

output_end:
	VMOVQ X13, CX
	VMOVQ X12, SI
	JMP   finish

merge_bytes:
	KMOVQ  K6,R13
	VPERMQ.Z Z19, Z0, K6, Z12

	VPORQ    Z19, Z12, Z19
	KSHIFTLQ $0x01, K6, K7
	KMOVQ  K7,R13
	KMOVQ  K6, R13
	KTESTD   K6, K7
	JZ       small_code_write_out
	KANDQ    K6, K7, K6
	JMP      merge_bytes

long_codes:
	ADDQ $0x00000038, BX
	SUBQ $0x00000040, DI

	// ; Merge event items
	// codes0 = keepEvenItems(litLenCodes)
	VMOVDQA32.Z Z14, K1, Z9

	// lens0 = keepEvenItems(litlenCodeLens)
	VMOVDQA32.Z Z15, K1, Z18

	// distCodes0 = keepEvenItems(distCodes)
	VMOVDQA32.Z Z16, K1, Z19

	// distCodes0 = distCodes0 << lens0
	VPSLLVQ Z18, Z19, Z19

	// codes0 = codes0 | distCodes0
	VPXORD Z19, Z9, Z9

	// totalLens = distCodeLens + litlenCodeLens
	VPADDD Z17, Z15, Z18

	// ; Merge odd items
	// codes1 = keepOddItems(litLenCodes)
	VPSRLQ $0x20, Z14, Z14

	// lens1 = keepOddItems(litlenCodeLens)
	VPSRLQ $0x20, Z15, Z15

	// distCodes = keepOddItems(distCodes)
	VPSRLQ $0x20, Z16, Z16

	// codes1 = codes1 + (distCodes << lens1) 
	VPSLLVQ Z15, Z16, Z16
	VPXORD  Z16, Z14, Z14

	// lens1 = keepOddItems(totalLens) 
	VPSRLQ $0x20, Z18, Z15

	// lens0 = keepEvenItems(totalLens) 
	VMOVDQA32.Z Z18, K1, Z18

	// ; Merge bitBuf bits
	VPSLLVQ Z13, Z9, Z9
	VPXORD  Z12, Z9, Z9
	VPADDQ  Z13, Z18, Z18

	// ; clear bits and bitLen
	XORQ      SI, SI
	XORQ      CX, CX
	VMOVDQU64 Z9, Z16
	VMOVDQU64 Z18, Z17
	VMOVDQU64 Z14, Z19
	VMOVDQU64 Z15, Z21
	CMPQ      DX, BX
	JA        overflow
	VMOVQ     X16, R9
	VMOVQ     X17, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ  $0x00000004, DI
	CMPQ  DX, BX
	JA    overflow
	VMOVQ X19, R9
	VMOVQ X21, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ    $0x00000004, DI
	CMPQ    DX, BX
	JA      overflow
	VPEXTRQ $0x01, X16, R9
	VPEXTRQ $0x01, X17, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ    $0x00000004, DI
	CMPQ    DX, BX
	JA      overflow
	VPEXTRQ $0x01, X19, R9
	VPEXTRQ $0x01, X21, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ          $0x00000004, DI
	VEXTRACTI32X4 $0x01, Z9, X16
	VEXTRACTI32X4 $0x01, Z18, X17
	VEXTRACTI32X4 $0x01, Z14, X19
	VEXTRACTI32X4 $0x01, Z15, X21
	CMPQ          DX, BX
	JA            overflow
	VMOVQ         X16, R9
	VMOVQ         X17, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ  $0x00000004, DI
	CMPQ  DX, BX
	JA    overflow
	VMOVQ X19, R9
	VMOVQ X21, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ    $0x00000004, DI
	CMPQ    DX, BX
	JA      overflow
	VPEXTRQ $0x01, X16, R9
	VPEXTRQ $0x01, X17, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ    $0x00000004, DI
	CMPQ    DX, BX
	JA      overflow
	VPEXTRQ $0x01, X19, R9
	VPEXTRQ $0x01, X21, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ          $0x00000004, DI
	VEXTRACTI32X4 $0x02, Z9, X16
	VEXTRACTI32X4 $0x02, Z18, X17
	VEXTRACTI32X4 $0x02, Z14, X19
	VEXTRACTI32X4 $0x02, Z15, X21
	CMPQ          DX, BX
	JA            overflow
	VMOVQ         X16, R9
	VMOVQ         X17, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ  $0x00000004, DI
	CMPQ  DX, BX
	JA    overflow
	VMOVQ X19, R9
	VMOVQ X21, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ    $0x00000004, DI
	CMPQ    DX, BX
	JA      overflow
	VPEXTRQ $0x01, X16, R9
	VPEXTRQ $0x01, X17, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ    $0x00000004, DI
	CMPQ    DX, BX
	JA      overflow
	VPEXTRQ $0x01, X19, R9
	VPEXTRQ $0x01, X21, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ          $0x00000004, DI
	VEXTRACTI32X4 $0x03, Z9, X16
	VEXTRACTI32X4 $0x03, Z18, X17
	VEXTRACTI32X4 $0x03, Z14, X19
	VEXTRACTI32X4 $0x03, Z15, X21
	CMPQ          DX, BX
	JA            overflow
	VMOVQ         X16, R9
	VMOVQ         X17, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ  $0x00000004, DI
	CMPQ  DX, BX
	JA    overflow
	VMOVQ X19, R9
	VMOVQ X21, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ    $0x00000004, DI
	CMPQ    DX, BX
	JA      overflow
	VPEXTRQ $0x01, X16, R9
	VPEXTRQ $0x01, X17, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ    $0x00000004, DI
	CMPQ    DX, BX
	JA      overflow
	VPEXTRQ $0x01, X19, R9
	VPEXTRQ $0x01, X21, R10

	// ; encode one symbol
	// sym = sym << bitLen
	SHLXQ CX, R9, R9

	// bits |= sym
	ORQ R9, SI

	// bitLen += length
	ADDQ R10, CX

	// *output = bits
	MOVQ SI, (DX)

	// temp = bitLen / 8
	MOVQ CX, R9
	SHRQ $0x03, R9

	// output += temp
	ADDQ R9, DX

	// temp = bitLen
	MOVQ CX, R9

	// bitLen = bitlen - (bitlen % 8)
	ANDQ $0xfffffff8, CX

	// bits =>> bitLen
	SHRXQ CX, SI, SI

	// bitLen = temp & 0b111
	MOVQ R9, CX
	ANDQ $0x00000007, CX

	// tokenPtr += 4
	ADDQ          $0x00000004, DI
	VEXTRACTI32X4 $0x04, Z9, X16
	VEXTRACTI32X4 $0x04, Z18, X17
	VEXTRACTI32X4 $0x04, Z14, X19
	VEXTRACTI32X4 $0x04, Z15, X21
	SUBQ          $0x00000038, BX
	VMOVQ         SI, X12
	VMOVQ         CX, X13
	CMPQ          DI, R8
	JA            overflow
	JMP           loop

finish:
overflow:
	MOVQ buf+32(FP), AX
	MOVQ SI, 32(AX)
	MOVQ CX, 40(AX)
	MOVQ (AX), CX
	SUBQ CX, DX
	MOVQ DX, 24(AX)
	MOVQ tokens_base+8(FP), AX
	SUBQ AX, DI
	SHRQ $0x02, DI
	MOVQ DI, ret+40(FP)
	RET

skip:
	MOVQ $0x00000000, AX
	MOVQ AX, ret+40(FP)
	RET