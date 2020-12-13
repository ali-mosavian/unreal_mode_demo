;;
;; gdtr.inc -- 386 protected mode stuff
;;                
                
ifndef          __gdtr_inc__
                __gdtr_inc__     equ 1


GDTR_T          struc
                size_                   word    ?
                offset_                 dword    ?
GDTR_T          ends


endif           ;; __gdtr_inc__

