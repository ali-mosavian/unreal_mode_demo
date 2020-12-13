;;
;; vbe.inc -- VBE definitions
;;                
                
ifndef          __vbe_inc__
                __vbe_inc__     equ 1

                include vdo.inc

                VBE_SIG                 equ     'ASEV'
                VBE_MIN_VER             equ     0200h
                               

                VBE                     equ     10h
                VBE_INFOBLOCK_GET       equ     4F00h
                VBE_MODEINFO_GET        equ     4F01h
                VBE_MODE_REQ            equ     4F02h
                VBE_MODE_GET            equ     4F03h
                VBE_WINCTRL             equ     4F05h
                VBE_GETSET_SCANLINE     equ     4F06h
                VBE_GETSET_START        equ     4F07h
                VBE_GETSET_DAC          equ     4F08h
                
                VBE_SET_SCANLINE        equ     0
                VBE_GET_SCANLINE        equ     1
                VBE_SET_SCANLINE_BYTES  equ     2
                VBE_SET_START           equ     0
                VBE_GET_START           equ     1
                VBE_SET_DAC             equ     0
                VBE_GET_DAC             equ     1
                
                VBE_WINDOWING           equ     00000001b
                VBE_WIN_READABLE        equ     00000010b
                VBE_WIN_WRITEABLE       equ     00000100b
                
                VBE_WIN_A               equ     0
                VBE_WIN_B               equ     1

                VBE_READWIN             equ     0
                VBE_WRITEWIN            equ     1
                VBE_READWRITEWIN        equ     2

VBE2IBLK        struct                          ;; INFOBLOCK
                vbeSignature            dword   VBE_SIG
                vbeVersion              word    ?
                oemStringPtr            dword   ?
                capabilities            dword   ?
                videoModePtr            dword   ?
                totalMemory             word    ?

                oemSoftwareRev          word    ?
                oemVendorNamePtr        dword   ?
                oemProductNamePtr       dword   ?
                oemProductRevPtr        dword   ?
                reserved                byte    222 dup (?)
                oemData                 byte    256 dup (?)
VBE2IBLK        ends

VBE2MIB         struct                           ;; MODEINFOBLOCK
                modeAttributes          word    ?
                winAAttributes          byte    ?
                winBAttributes          byte    ?
                winGranularity          word    ?
                winSize                 word    ?
                winASegment             word    ?
                winBSegment             word    ?
                winFuncPtr              dword   ?
                bytesPerScanLine        word    ?

                xResolution             word    ?
                yResolution             word    ?
                xCharSize               byte    ?
                yCharSize               byte    ?
                numberOfPlanes          byte    ?
                bitsPerPixel            byte    ?
                numberOfBanks           byte    ?
                memoryModel             byte    ?
                bankSize                byte    ?
                numberOfImagePages      byte    ?
                                        byte    ?
                      
                redMaskSize             byte    ?
                redFieldPosition        byte    ?
                greenMaskSize           byte    ?
                greenFieldPosition      byte    ?
                blueMaskSize            byte    ?
                blueFieldPosition       byte    ?
                rsvdMaskSize            byte    ?
                rsvdFieldPosition       byte    ?
                directColorModeInfo     byte    ?

                physBasePtr             dword   ?
                offScreenMemOffset      dword   ?
                offScreenMemSize        word    ?
                                        byte    206 dup (?)
VBE2MIB         ends


;;::::::::
rgb MACRO red, green, blue
    EXITM % red SHL 16 + green SHL 8 + blue
ENDM


endif           ;; __vbe_inc__

