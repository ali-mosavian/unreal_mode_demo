                .model tiny, pascal
                .586p
                option proc: private

                include vdo.inc
                include vbe.inc
                include gdt.inc


;;::::::::
exitError       proto   near, :word
vdoSetMode      proto   near, :word, :word
vdoGetMode      proto   near, :word, :far ptr
vdoFindMode     proto   near, :word, :word, :word
drwRectGrad     proto   near, :dword, :word, :word, :dword, :dword, :dword, :dword
prints          proto   near, :far ptr
enterUnrealM    proto   near



;;::::::::
.code
.startup:
                call main

;;::::::::
main            proc    near
                local   vdo_mode_no: word,\
                        vdo_mode_info: VBE2MIB
@@:
                ; Get default video mode
                mov     ax, VDO_MODE_GET
                int     VDO
                mov     vdo$initial_mode_no, al

                ;; Attempt to setup unreal mode
                invoke  enterUnrealM

                ;; Find matching video mode                
                invoke  vdoFindMode, 640, 480, 32
                mov     vdo_mode_no, ax
                cmp     ax, 0
                jg      @F

                push    offset msg$vbe_no_match
                call    exitError
@@:
                ;; Get information about video mode
                mov     ax, ss
                shl     eax, 16
                lea     ax, vdo_mode_info
                invoke  vdoGetMode, vdo_mode_no, eax
                or      ax, ax
                jnz     @F

                push    offset msg$vbeGetMIBFail
                call    exitError


@@:             ;; Set video mode
                invoke  vdoSetMode, vdo_mode_no, 1
                or      ax, ax
                jnz     @F

                push    offset msg$vbeSetModeFail
                call    exitError

@@:
                invoke  drwRectGrad,\
                        vdo_mode_info.physBasePtr,\
                        vdo_mode_info.xResolution,\
                        vdo_mode_info.yResolution,\
                        rgb(236, 249, 87),
                        rgb(121, 38, 96),
                        rgb(12, 12, 255),
                        rgb(247, 69, 204)

                call    kbd_wait

@exit:
                xor     ax, ax
                mov     al, vdo$initial_mode_no
                int     VDO

                call    dos_exit
main            endp    

;:::::
prints         proc    near uses ax dx es di,\
                        str_:far ptr

                les     di, str_
@@:
                mov     dl, es:[di]
                or      dl, dl
                jz      @F
                mov     ah, 02h
                int     21h
                inc     di
                jmp     @B

@@:
                ret
prints         endp


;:::::
dos_exit        proc    near
                ; Return to DOS with value 0
                mov     ax, 04c00h
                int     21h
dos_exit        endp


;:::::
exitError      proc     near,\
                        err_msg_:word

                ;; Restore video mode
                xor     ax, ax
                mov     al, vdo$initial_mode_no
                int     VDO

                ;; Print error message & exit
                push    cs
                push    err_msg_
                call    prints

                call    dos_exit                        
exitError      endp


;:::::
kbd_wait        proc    near private
@@:             xor     ax, ax
                int     16h
                or      ah, ah        
                jz      @B
                
                ret
kbd_wait        endp


;:::::
vdoGetMode      proc    near uses cx di es,\
                        mode_num:word,\
                        mode_info:far ptr                
                mov     cx, mode_num
                les     di, mode_info
                mov     ax, VBE_MODEINFO_GET
                int     VBE

                cmp     ax, 4fh
                je      @F        
                xor     ax, ax
@@:
                and     ax, 1
                ret
vdoGetMode      endp


;:::::
vdoFindMode     proc    near uses es di edx,\
                        x_res:word,\
                        y_res:word,\
                        bpp:word

                local   vbe_info:VBE2IBLK,\
                        vbe_mode_info:VBE2MIB

                ;; Get VBE info block
                push    ss
                pop     es 
                lea     di, vbe_info
                mov     ax, VBE_INFOBLOCK_GET
                int     VBE           

                cmp     ax, 4fh
                je      @F
                mov     ax, -2
                jmp     @exit
@@:
                ;; Check VBE version
                cmp     vbe_info.vbeVersion, VBE_MIN_VER
                jge     @F

                mov     ax, -3
                jmp     @exit

@@:
                ;; Go through modes
                mov     dx, ss
                shl     edx, 16
                lea     dx, vbe_mode_info
                les     di, vbe_info.videoModePtr
@loop:                
                
                mov     ax, es:[di]
                cmp     ax, -1
                je      @exit

                ;; Get mode info
                push    edx
                push    ax
                invoke  vdoGetMode, ax, edx
                or      ax, ax
                pop     ax
                pop     edx
                jz      @F

                ;; Check for a match
                mov     bx, vbe_mode_info.xResolution
                cmp     bx, x_res
                jne     @F

                mov     bx, vbe_mode_info.yResolution
                cmp     bx, y_res
                jne     @F

                movzx   bx, vbe_mode_info.bitsPerPixel
                cmp     bx, bpp
                jne     @F

                cmp     vbe_mode_info.numberOfPlanes, 1
                jne     @F

                ;; Found a match!
                jmp     @exit

@@:
                add     di, 2
                jmp     @loop


@exit:                
                ret
vdoFindMode     endp


;:::::
vdoSetMode      proc    near uses es di edx,\
                        mode:word,\
                        use_lfb:word                

                ;; Use LFB ?
                xor     bx, bx
                mov     ax, use_lfb
                or      ax, ax
                jz      @F
                mov     bx, 4000h
@@:
                ;; Set mode
                mov     ax, VBE_MODE_REQ
                add     bx, mode
                int     VBE

                cmp     ax, 04Fh
                je      @F
                xor     ax, ax
@@:             
                and     ax, 1
                ret
vdoSetMode      endp




;:::::
drwScanline     proc    near uses es eax ebx ecx edx edi esi,\
                        p_lfb:dword,
                        _width:word,
                        r1: dword,
                        g1: dword,
                        b1: dword,
                        r2: dword,
                        g2: dword,
                        b2: dword

                local drdx: dword, \
                      dgdx: dword, \
                      dbdx: dword

@start:
                ;; Calculate drdx, dgdx, dbdx
                movzx   ecx, _width
                
                mov     eax, r2
                sub     eax, r1
                cdq
                idiv    ecx
                mov     drdx, eax

                mov     eax, g2
                sub     eax, g1
                cdq
                idiv    ecx
                mov     dgdx, eax

                mov     eax, b2
                sub     eax, b1
                cdq
                idiv    ecx
                mov     dbdx, eax


                ;; Counter and frame buffer pointer
                xor     ax, ax
                mov     es, ax
                mov     esi, p_lfb

                movzx   edi, _width
                shl     edi, 2

                add     esi, edi
                neg     edi             
                mov     ebx, r1
                mov     ecx, g1
                ror     ecx, 16
                mov     edx, b1
                ror     edx, 16

                ;; Modify loop constants
                mov     eax, drdx
                mov     dword ptr cs:[@drdx_fixup+3], eax
                
                mov     eax, dgdx
                ror     eax, 16
                mov     word ptr cs:[@dgdx_fixup_i+2], ax
                xor     ax, ax
                mov     dword ptr cs:[@dgdx_fixup_f+3], eax

                mov     eax, dbdx
                ror     eax, 16
                mov     word ptr cs:[@dbdx_fixup_i+2], ax
                xor     ax, ax
                mov     dword ptr cs:[@dbdx_fixup_f+3], eax

        @@:
                mov     eax, ebx
                mov     ah, cl
                mov     al, dl
                mov     es:[esi+edi], eax

@drdx_fixup:    add     ebx, 0deadbeefh         ;drdx
@dgdx_fixup_f:  add     ecx, 0beef0000h         ;dgdx fraction
@dgdx_fixup_i:  adc     cx,  0deadh             ;dgdx integer
@dbdx_fixup_f:  add     edx, 0beef0000h         ;dbdx fraction
@dbdx_fixup_i:  adc     dx,  0deadh             ;dgdx integer

                add     edi, 4
                jnz     @b

                ret
drwScanline     endp


;:::::
drwRectGrad       proc  near uses eax ebx ecx edx,\
                        p_lfb: dword,\
                        width_: word,\
                        height_: word,\
                        c1: dword,\
                        c2: dword,\
                        c3: dword,\
                        c4: dword

                local l_r: dword, \
                      l_g: dword, \
                      l_b: dword, \
                      r_r: dword, \
                      r_g: dword, \
                      r_b: dword, \
                      l_drdy: dword, \
                      l_dgdy: dword, \
                      l_dbdy: dword, \
                      r_drdy: dword, \
                      r_dgdy: dword, \
                      r_dbdy: dword

                
                ;; l_r = ((c1 & 0xff0000) >> 0);
                ;; l_g = ((c1 & 0x00ff00) << 8);
                ;; l_b = ((c1 & 0x0000ff) << 16);
                mov     ebx, c1

                mov     eax, ebx
                and     eax, 000ff0000h
                mov     l_r, eax

                xor     eax, eax
                mov     ah, bh
                shl     eax, 8
                mov     l_g, eax

                xor     eax, eax
                mov     al, bl
                shl     eax, 16
                mov     l_b, eax
                
                ;; l_drdy = (((c4 & 0xff0000) >> 0)-l_r)/height;
                ;; l_dgdy = (((c4 & 0x00ff00) << 8)-l_g)/height;
                ;; l_dbdy = (((c4 & 0x0000ff) << 16)-l_b)/height;
                mov     ebx, c4
                movzx   ecx, height_ 

                mov     eax, ebx
                and     eax, 000ff0000h
                sub     eax, l_r
                cdq
                idiv    ecx
                mov     l_drdy, eax

                xor     eax, eax
                mov     ah, bh
                shl     eax, 8  
                sub     eax, l_g
                cdq
                idiv    ecx
                mov     l_dgdy, eax

                xor     eax, eax
                mov     al, bl
                shl     eax, 16 
                sub     eax, l_b
                cdq
                idiv    ecx
                mov     l_dbdy, eax

                ;; r_r = ((c2 & 0xff0000) >> 0);
                ;; r_g = ((c2 & 0x00ff00) << 8);
                ;; r_b = ((c2 & 0x0000ff) << 16);
                mov     ebx, c2

                mov     eax, ebx
                and     eax, 0ff0000h
                mov     r_r, eax

                xor     eax, eax
                mov     ah, bh
                shl     eax, 8
                mov     r_g, eax

                xor     eax, eax
                mov     al, bl
                shl     eax, 16
                mov     r_b, eax
                
                ;; r_drdy = (((c3 & 0xff0000) >> 0)-r_r)/height;
                ;; r_dgdy = (((c3 & 0x00ff00) << 8)-r_g)/height;
                ;; r_dbdy = (((c3 & 0x0000ff) << 16)-r_b)/height;
                mov     ebx, c3
                movzx   ecx, height_

                mov     eax, ebx
                and     eax, 0ff0000h
                sub     eax, r_r
                cdq
                idiv    ecx
                mov     r_drdy, eax

                xor     eax, eax
                mov     ah, bh
                shl     eax, 8  
                sub     eax, r_g
                cdq
                idiv    ecx
                mov     r_dgdy, eax

                xor     eax, eax
                mov     al, bl
                shl     eax, 16 
                sub     eax, r_b
                cdq
                idiv    ecx
                mov     r_dbdy, eax             

                
                ;;      for (uint16_t y = 0; y < height; y++)
        @@:
                invoke  drwScanline, p_lfb, width_, l_r, l_g, l_b, r_r, r_g, r_b

                ;; p_lfb += width;
                ;; l_r += l_drdy;
                ;; l_g += l_dgdy;
                ;; l_b += l_dbdy;
                ;; r_r += r_drdy;
                ;; r_g += r_dgdy;
                ;; r_b += r_dbdy;
                movzx   eax, width_
                shl     eax, 2
                add     p_lfb, eax

                mov     eax, l_drdy
                add     l_r, eax
                mov     eax, l_dgdy
                add     l_g, eax
                mov     eax, l_dbdy
                add     l_b, eax

                mov     eax, r_drdy
                add     r_r, eax
                mov     eax, r_dgdy
                add     r_g, eax
                mov     eax, r_dbdy
                add     r_b, eax

                dec     height_
                jnz     @b

                ret
drwRectGrad       endp


;:::::
enterUnrealM    proc    near uses ds es fs gs    
                local   gdtr:GDTR_T
                
                smsw    ax
                test    ax, 1
                jnz     @fail

                cli
                call    a20_enable

                ; Patch gdtr info using linear address
                mov     gdtr.size_, gdt_end-gdt_start
                mov     eax, cs
                shl     eax, 4
                add     eax, gdt_start
                mov     gdtr.offset_, eax

                ; Load gdt register
                lgdt    fword ptr gdtr

                ; Switch to pmode
                mov     eax, cr0
                or      al, 1
                mov     cr0, eax

                ; Flush pipeline of 386/486 will crash
                jmp     $+2

                ;;;;;;;;
                ; CPU now running in protected mode
                ;;;;;;;;

                ;mov    bx, 08h
                db 066h,0BBh,08h,00h
                ;mov    ds, bx
                db 08Eh,0DBh
                ;mov    es, bx
                db 08Eh,0C3h
                ;mov    fs, bx
                db 08Eh,0E3h
                ;mov    gs, bx
                db 08Eh,0EBh
                ; and   al, 0feh
                db 024h,0FEh
                ; mov   cr0, eax
                db 0Fh,22h,0C0h
                jmp     $+2

                ;;;;;;;;
                ; CPU now running in 16-bit mode again
                ;;;;;;;;

@@:             
                sti
                ret

@fail:                
                push    offset msg$alreadyInPmode
                call    exitError
enterUnrealM   endp


;:::::
a20_enable      proc    near uses ax cx

                call    @test_a20               ; is A20 already enabled?
                jz      @a20_enabled            ; if yes, done
                in      al, 92h                 ; PS/2 A20 enable
                or      al, 2
                out     92h, al
                call    @test_a20               ; is A20 enabled?
                jz      @a20_enabled            ; if yes, done
                call    @kb_wait                ; AT A20 enable
                jnz     @a20_enabled
                mov     al, 0D1h
                out     64h, al
                call    @kb_wait
                jnz     @a20_enabled
                mov     al, 0DFh
                out     60h, al
                call    @kb_wait
                jmp     @a20_enabled


@kb_wait:                               ; wait for safe to write to 8042
                xor     cx, cx
                in      al, 64h                 ; read 8042 status
                test    al, 2                   ; buffer full?
                loopnz  @kb_wait                        ; if yes, loop
                retn

@test_a20:                              ; test for enabled A20
                push    es
                push    fs

                push    0
                pop     es
                push    0ffffh
                pop     fs

                mov     al, [es:0]                      ; get byte from 0:0
                mov     ah, al                  ; preserve old byte
                not     al                      ; modify byte
                xchg    al, [fs:10h]    ; put modified byte to 0FFFFh:10h
                cmp     ah, [es:0]                      ; set zero if byte at 0:0 not modified
                mov     [fs:10h], al    ; restore byte at 0FFFFh:10h
                
                pop     fs
                pop     es
                retn                            ; return, zero if A20 enabled

@a20_enabled:
                ret
a20_enable      endp


;;::::::::
msg$alreadyInPmode      db "Error: CPU already in protected mode", 0ah, 0dh, 0
msg$vbeGetMIBFail       db "Error: Failed to get VESA mode info", 0ah, 0dh, 0
msg$vbeSetModeFail      db "Error: Failed to set VESA mode", 0ah, 0dh, 0        
msg$vbe_no_match        db "Error: Could not find requested mode", 0ah, 0dh, 0 


;;::::::::
vdo$initial_mode_no     db ?


;;::::::::
gdt_start:      
        ; First entry is always the Null Descriptor
        dd 0
        dd 0            
gdt_data:        
        dw 0ffffh       ; Limit[0:15]
        dw 0000h        ; Base[0:15]
        db 00h          ; Base[23:16]
        db 10010010b    ; Pr=1, DPL=00 (ring 0), DT=1, Code=0, DC=0, RW=1 (W), A=0
        db 11001111b    ; G=1 (4K/pages), Sz=1 (32bit), IGNORE=00, Limit[23:16] = 0fh
        db 0000h        ; Base[31:24]
gdt_end:


END