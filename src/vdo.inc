;;
;; vdo.inc -- video BIOS definitions
;;                

ifndef          __vdo_inc__
                __vdo_inc__     equ 1

                VDO             equ     10h
                VDO_FRMBUFF     equ     0A000h
                VDO_MODE_GET    equ     00F00h

endif           ;; __vdo_inc__
