              PAGE     60, 120
              TITLE    CALENDA2 - PM Calendar Function

;------------------------------------------------------------------------------
;
;                      Copyright (c) 1990  BEST SOFTWARE
;
;
;               CALENDA2.ASM - PM Calendar Program (part 2 of 2)
;
;------------------------------------------------------------------------------
              PAGE
              .MODEL   SMALL, PASCAL

;------------------------------------------------------------------------------
;  External references
;------------------------------------------------------------------------------

              EXTRN    convert_num_1: PROC

;------------------------------------------------------------------------------
;  Include files
;------------------------------------------------------------------------------

              .SALL
              .XLIST
              INCLUDE  common.inc
INCL_DOS      EQU      1
INCL_WIN      EQU      1
INCL_GPI      EQU      1
              INCLUDE  os2.inc
              .LIST

PARAMETERS    STRUC
parm_month    DW       ?
parm_year     DW       ?
PARAMETERS    ENDS
              PAGE
;------------------------------------------------------------------------------
;  Data and constants
;------------------------------------------------------------------------------

              .CONST

normal_year   DB       31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
leap_year     DB       31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

two_digits    DB       '99'
              PAGE
              .286
              .CODE
;------------------------------------------------------------------------------
;  Window procedure for 'CALENDAR' class
;------------------------------------------------------------------------------

calendar_proc PROC     FAR USES ds,                                            \
                       hwnd: DWORD, msg: WORD, mp1: DWORD, mp2: DWORD

              LOCAL    parm_pointer: FAR PTR,                                  \
                       hps: DWORD,                                             \
                       rectl [SIZ RECTL]: BYTE,                                \
                       buffer [10]: BYTE,                                      \
                       x_increment: WORD, x_offset: WORD, x_size: WORD,        \
                       y_increment: WORD, y_offset: WORD,                      \
                       day_number: BYTE, day_max: BYTE,                        \
                       x_counter: BYTE, y_counter: BYTE,                       \
                       datetime [SIZ DATETIME]: BYTE, current_flag: BYTE

parm_offset   EQU      WPT parm_pointer
parm_seg      EQU      WPT parm_pointer + 2

point_2       EQU      rectl.rcl_xRight


;  Establish addressability to data segment

              mov      ax, @data              ; get address
              mov      ds, ax                 ;  of data segment

;  Get address of saved parameter segment

              @WinQueryWindowPtr hwnd, 0, parm_pointer

;  Examine message and route to applicable code

              @route   msg,                                                    \
                       WM_CREATE, do_create,                                   \
                       WM_SETWINDOWPARAMS, do_setwindowparams,                 \
                       WM_PAINT, do_paint,                                     \
                       WM_DESTROY, do_destroy

;  No applicable code this message, do default processing
default:
              @WinDefWindowProc hwnd, msg, mp1, mp2

;  Exit window procedure with current return code in dx:ax
return:
              ret                             ; return


;  WM_CREATE processing:
;     allocate segment for local copy of parameters,
;     set address of this segment of window pointer
do_create:
              @DosAllocSeg <SIZ PARAMETERS>, parm_seg, SEG_NONSHARED

              mov      parm_offset, 0         ; set area offset
              les      di, parm_pointer       ; local copy area address
              @WinSetWindowPtr hwnd, 0, es:di

              @return  0                      ; return


;  WM_SETWINDOWPARAMS processing:
;     get parameters passed to class and saved in allocated segment,
;     call for window repaint
do_setwindowparams:
              les      di, mp1                ; get address in window params
              les      di, es: wprm_pszText [di]  ; parameter address
              mov      ax, es: [di]           ; get input month
              mov      dx, es: [di + 2]       ; get input year
              les      di, parm_pointer       ; local copy area address
              mov      es: parm_month [di], ax    ; set month
              mov      es: parm_year [di], dx ; set year

              @WinInvalidateRegion hwnd, NULL, FALSE

              @return  1                      ; return


;  WM_PAINT processing:
;     paint the area for the 'CALENDAR' class
do_paint:

;  Clear direction flag

              cld                             ; clear direction flag

;  Get the current day, month and year and check if selected month and year is
;   current. If so, set indicator flag.

              @DosGetDateTime datetime

              les      di, parm_pointer       ; parameter address
              mov      current_flag, 0        ; indicate not current month/year
              mov      ax, es: parm_month [di]    ; get specified month
              cmp      al, datetime.date_month    ; current month?
              jne      @f                     ; no, skip
              mov      ax, es: parm_year [di] ; get specified year
              cmp      ax, datetime.date_year ; current year?
              jne      @f                     ; no, skip
              mov      current_flag, 1        ; indicate current month/year

;  Get number of days in specified month

@@:           mov      ax, es: parm_month [di]    ; get specified month
              dec      ax                     ; absolute number
              mov      bx, OFF normal_year    ; address normal table
              test     BPT es: parm_year [di], 3  ; leap year?
              jnz      @f                     ; no, skip
              mov      bx, OFF leap_year      ; address leap year table
@@:           xlat                            ; get days this month
              mov      day_max, al            ;  and save result

;  This logic computes the day in week for given month and year

              mov      ax, es: parm_year [di] ; specified year
              dec      ax                     ; absolute
              mov      dx, ax                 ; copy year
              shr      ax, 2                  ; year / 4
              imul     ax, 5                  ; (year / 4) * 5
              and      dx, 3                  ; (year / 4) * 5 + 3
              add      ax, dx                 ; (year / 4) * 5 + 3 + year

              mov      cx, es: parm_month [di]    ; get specified month
              dec      cx                     ; absolute
              jz       do_paint_1             ; first month, skip

@@:           add      al, [bx]               ; add days
              adc      ah, 0                  ;  in month
              inc      bx                     ; update table entry address
              loop     @b                     ; next month

;  Compute offset in calendar (ie. day in week for 1st of month)
do_paint_1:
              dec      ax                     ; adjust
              cwd                             ;  and set for divide
              mov      cx, 7                  ; days in week
              div      cx                     ; divide
              neg      dl                     ; offset in calendar
              mov      day_number, dl         ; save it

;  Get the dimensions of the window and fill with coloured box

              @WinQueryWindowRect hwnd, rectl

              @WinBeginPaint hwnd, NULL, NULL, hps

              @GpiMove hps, rectl
              @GpiSetColor hps, CLR_PALEGRAY
              @GpiBox  hps, DRO_FILL, point_2, 20, 20

;  Divide into grid 6 rows by 7 columns,
;   save height/width as x/y increment and set offset to half remainder

              mov      ax, WPT rectl.rcl_xRight   ; window height
              cwd                             ; set for divide
              mov      cx, 7                  ; number of rows
              div      cx                     ; row height
              mov      x_increment, ax        ; save it as increment
              shr      dx, 1                  ; halve remainder
              mov      x_offset, dx           ; save it as offset
              mov      ax, WPT rectl.rcl_yTop ; window width
              cwd                             ; set for divide
              mov      cx, 6                  ; number of columns
              div      cx                     ; column width
              mov      y_increment, ax        ; save it as increment
              shr      dx, 1                  ; halve remainder
              mov      y_offset, dx           ; save it as offset

;  Compute placement of two digits within cell and save as cell width for write

              mov      ax, x_increment        ; get cell width
              mov      WPT rectl.rcl_xRight, ax   ; set as rectl width
              mov      ax, y_increment        ; get cell height
              mov      WPT rectl.rcl_yTop, ax ; set as rectl height

              @WinDrawText hps, 2, two_digits, rectl, NULL, NULL,              \
                       <DT_CENTER OR DT_QUERYEXTENT>

              mov      ax, WPT rectl.rcl_xRight   ; offset following right digit
              mov      x_size, ax             ; save it as used cell size

;  Get window address of first line

              imul     ax, y_increment, 5     ; length to top row
              add      ax, y_offset           ; plus offset
              mov      WPT rectl.rcl_yBottom, ax  ; save as lower coordinates
              add      ax, y_increment        ; plus cell height
              mov      WPT rectl.rcl_yTop, ax ; save as upper coordinates

;  Line count

              mov      y_counter, 6           ; row count

;  Get window address of first column
do_paint_2:
              mov      ax, x_offset           ; length to left column
              mov      WPT rectl.rcl_xLeft, ax    ; save as left coordinates
              add      ax, x_size             ; plus used cell width
              mov      WPT rectl.rcl_xRight, ax   ; save as right coordinates

;  Column count

              mov      x_counter, 7           ; column count

;  Get day number and increment, check if in range
do_paint_3:
              mov      al, day_number         ; get day number
              inc      al                     ; update
              mov      day_number, al         ;  and save result
              jle      do_paint_4             ; less than 1, skip
              cmp      al, day_max            ; exceeds days this month?
              ja       do_paint_5             ; yes, all done

;  Set text colour depending on whether day/month/year is current

              mov      cx, CLR_NEUTRAL        ; set neutral colour
              cmp      current_flag, 1        ; is month/year current?
              jne      @f                     ; no, use neutral
              cmp      al, datetime.date_day  ; is day number today's?
              jne      @f                     ; no, use neutral
              mov      cx, CLR_WHITE          ; current day/month/year, white

;  Set buffer address and convert day number

@@:           push     ss                     ; copy address
              pop      es                     ;  of stack segment
              lea      di, buffer             ; address of buffer
              call     convert_num_1          ; convert day number
              mov      BPT es: [di], 0        ; set null terminator

;  Set day number in cell in window

              @WinDrawText hps, -1, buffer, rectl, cx, CLR_BACKGROUND,         \
                       <DT_RIGHT OR DT_VCENTER>

;  Update x coordindate and loop if more to do
do_paint_4:
              mov      ax, x_increment        ; get x increment
              add      WPT rectl.rcl_xLeft, ax    ;  and update
              add      WPT rectl.rcl_xRight, ax   ;  cell x coordinate

              dec      x_counter              ; update column counter
              jnz      do_paint_3             ; more columns, loop

;  Update y coordindate and loop if more to do

              mov      ax, y_increment        ; get y increment
              sub      WPT rectl.rcl_yBottom, ax  ;  and update
              sub      WPT rectl.rcl_yTop, ax ;  cell y coordinate

              dec      y_counter              ; update row number
              jnz      do_paint_2             ; more rows, loop

;  Paint complete, free hps
do_paint_5:
              @WinEndPaint hps

              @return  0                      ; return


;  WM_DESTROY processing:
;     free local parameter segment
do_destroy:
              @DosFreeSeg parm_seg

              @return  0                      ; return


calendar_proc ENDP
              PAGE
              END



