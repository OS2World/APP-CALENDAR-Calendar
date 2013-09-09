              PAGE     60, 120
              TITLE    CALENDAR - PM Calendar Function

;------------------------------------------------------------------------------
;
;                      Copyright (c) 1990  BEST SOFTWARE
;
;
;               CALENDAR.ASM - PM Calendar Program (part 1 of 2)
;
;
;  A simple OS/2 program to demonstate use of a dialog box as the main window
;  and escapsulation of drawing function for windows. The program displays
;  a calendar for the selected month and year, and allows for months prior/
;  following to be selected and displayed.
;
;
;  This program was written as an exercise in what I hoped to be 'object-
;  oriented graphical programming' ... or at least what I could do with
;  the existing OS/2 model and tools. The creation of the program began
;  with layout of what I wanted the output to look like and for this I used
;  the dialog box editor and set the location for text, push buttons etc. I
;  also defined an area for the 'calendar' data with the user-defined class of
;  'CALENDAR'. This appears as a red box in the editor, and what the contents
;  will look like is up to the window procedure associated with the class.
;
;  The base logic is all conventional window stuff but my main window is the
;  dialog box created as the resource above. The starting month and year is sent
;  to the escapsulated calendar procedure and retained by the instance of that
;  'object'. The  month/year is also sent when changed by pressing the
;  previous/next buttons.  As far as the program is concerned, the calendar data is
;  drawn asynchronously to the main logic.
;
;  It would appear that the lack of a normal client window imposes limitations
;  on the use of a dialog box as a substitute main window. For example, the
;  FCF_ICON and WS_MINIMIZED settings are ignored when the dialog box is
;  loaded. Both these can be bypassed by specifically setting the icon and
;  sending a minimize message. The remaining problem is that when the dialog
;  box is minimized, the icon is overlaid with a portion of the left-hand
;  pushbutton. I have found no way round this, thus the ability to minimize
;  the window has been removed. (Note that it is possible to define a client
;  window but this will cause all the controls to be overlaid when using the
;  dialog box editor.) If you have any suggestions, I would be very pleased to
;  hear of them!
;
;
;  Assembly of this program (calendar.asm and calenda2.asm) requires Win/Gpi
;  macro definitions not present in the IBM OS/2 Toolkit. Additional
;  macros/equates in common.inc are also required but not provided.
;
;
;  Stephen Best
;  October, 1990
;
;
;  Any inquiries/suggestions etc, please contact
;
;     BEST SOFTWARE
;     P.O. Box 3097
;     Manuka  A.C.T.  2603
;     Australia
;
;------------------------------------------------------------------------------
              PAGE
              .MODEL   SMALL, PASCAL
              DOSSEG

;------------------------------------------------------------------------------
;  External references
;------------------------------------------------------------------------------

              EXTRN    calendar_proc: PROC

;------------------------------------------------------------------------------
;  Include files
;------------------------------------------------------------------------------

              .SALL
              .XLIST
              INCLUDE  common.inc
INCL_DOS      EQU      1
INCL_WIN      EQU      1
              INCLUDE  os2.inc
              .LIST

              INCLUDE  calendar.inc
              PAGE
;------------------------------------------------------------------------------
;  Data and constants
;------------------------------------------------------------------------------

              .CONST

class         DB       'CALENDAR', 0
window_title  DB       'Calendar', 0
month_of_year LABEL    BYTE
              @list    'January', 'February', 'March', 'April',                \
                       'May', 'June', 'July', 'August',                        \
                       'September', 'October', 'November', 'December'

menu_line_1   MENUITEM <MIT_END, MIS_SEPARATOR, 0, 0, NULL, NULL>
menu_line_2   MENUITEM <MIT_END, MIS_TEXT, 0, ID_ABOUT, NULL, NULL>
menu_text_2   DB       '~About Calendar...', 0

              .DATA

parameters    LABEL    BYTE
current_month DW       ?
current_year  DW       ?
              PAGE
              .286
              .CODE

;------------------------------------------------------------------------------
;  Main procedure
;------------------------------------------------------------------------------

main          PROC     FAR

              LOCAL    hab: DWORD, hmq: DWORD, qmsg [SIZ QMSG]: BYTE,          \
                       hdlg_frame: DWORD, hwnd_sysmenu: DWORD,                 \
                       menuitem_sysmenu [SIZ MENUITEM]: BYTE

hwnd_submenu  EQU      menuitem_sysmenu.mi_hwndSubMenu


;  Initialize the application and create message queue

              @WinInitialize NULL, hab

              @WinCreateMsgQueue hab, 0, hmq

;  Register the private class 'CALENDAR' for the calendar component
;   of the dialog box. Load the dialog box resource as our main
;   window and process.

              @WinRegisterClass hab, class, calendar_proc, NULL, 4

              @WinLoadDlg HWND_DESKTOP, HWND_DESKTOP, window_proc,             \
                       NULL, ID_RESOURCE, NULL, hdlg_frame

;  Add lines at the bottom of the system menu for 'About...' processing

              @WinWindowFromID hdlg_frame, FID_SYSMENU, hwnd_sysmenu

              @WinSendMsg hwnd_sysmenu, MM_ITEMIDFROMPOSITION, NULL, NULL

              xchg     ax, cx                 ; copy id
              @WinSendMsg hwnd_sysmenu, MM_QUERYITEM, cx, *menuitem_sysmenu

              @WinSendMsg hwnd_submenu, MM_INSERTITEM, *menu_line_1, NULL
              @WinSendMsg hwnd_submenu, MM_INSERTITEM, *menu_line_2,           \
                       *menu_text_2

;  Message loop processing ... drop out on WM_QUIT message
@@:
              @WinGetMsg hab, qmsg, NULL, 0, 0
              or       ax, ax                 ; WM_QUIT posted?
              jz       @f                     ; yes, exit loop
              @WinDispatchMsg hab, qmsg
              jmp      @b                     ; loop

;  Termination processing, destroy window
@@:
              @WinDestroyWindow hdlg_frame

;  Destroy message queue and terminate application

              @WinDestroyMsgQueue hmq

              @WinTerminate hab

;  Exit with zero return code

              @DosExit EXIT_PROCESS, 0


main          ENDP
              PAGE
;------------------------------------------------------------------------------
;  Dialog box procedure for ID_RESOURCE
;------------------------------------------------------------------------------

window_proc   PROC     FAR USES ds,                                            \
                       hwnd: DWORD, msg: WORD, mp1: DWORD, mp2: DWORD

              LOCAL    datetime [SIZ DATETIME]: BYTE,                          \
                       buffer [50]: BYTE


;  Establish addressability to data segment

              mov      ax, @data              ; get address of
              mov      ds, ax                 ;  data segment

;  Examine message and route to applicable code

              @route   msg,                                                    \
                       WM_INITDLG, do_initdlg,                                 \
                       WM_COMMAND, do_command,                                 \
                       WM_CLOSE, do_close

;  No applicable code this message, do default processing
default:
              @WinDefDlgProc hwnd, msg, mp1, mp2

;  Exit dialog procedure with current return code in dx:ax
return:
              ret                             ; return


;  WM_INITDLG processing:
;     get current month and year and save in static area,
;     convert month and year and send to ID_MONTHYEAR control,
;     send current month and year to ID_CALENDAR window procedure
;      for drawing main calendar area,
;     get previous, next months and send to ID_PREVIOUS, ID_NEXT
;      push-button controls.
do_initdlg:
              @DosGetDateTime datetime        ; get start month, year
              mov      al, datetime.date_month    ; get month number
              cbw                             ; now word
              mov      current_month, ax      ; save current month
              mov      ax, datetime.date_year ; get year number
              mov      current_year, ax       ; save current year

;  Common output code for initialization and update of controls
;   when month/year changed.
do_initdlg_1:

;  Send completed month, year string to static text control

              mov      ax, current_month      ; get current month
              mov      bx, OFF month_of_year  ; address translate table
              xlat                            ; get offset to string
              xchg     ax, si                 ; now in si
              add      si, bx                 ; month string start addr

              cld                             ; clear copy direction
              push     ss                     ; copy ss
              pop      es                     ;  to es
              lea      di, buffer             ; buffer start address
@@:           lodsb                           ; get byte of string
              or       al, al                 ; null terminator?
              jz       @f                     ; yes, skip
              stosb                           ; no, store in buffer
              jmp      @b                     ;  and loop

@@:           mov      ax, '  '               ; two blanks
              stosw                           ; set as separator

              mov      ax, current_year       ; get year
              mov      cl, 100                ; divisor
              div      cl                     ; divide by 100
              call     convert_num            ; convert, move to buffer
              xchg     ah, al                 ; restore remainder
              call     convert_num            ; convert, move to buffer

              mov      BPT es: [di], 0        ; set terminator

              @WinSetDlgItemText hwnd, ID_MONTHYEAR, buffer

;  Send current month and year to calendar drawing function

              @WinSetDlgItemText hwnd, ID_CALENDAR, parameters

;  Get previous month as string and send to ID_PREVIOUS
;   push-button control

              mov      ax, current_month      ; get current month
              dec      ax                     ; number previous month
              jnz      @f                     ; same year, ok
              mov      ax, 12                 ; set to 12th month last
@@:           mov      bx, OFF month_of_year  ; address translate table
              xlat                            ; get offset to string
              add      bx, ax                 ; month string start addr
              @WinSetDlgItemText hwnd, ID_PREVIOUS, ds:bx

;  Get next month as string and send to ID_NEXT push-button control

              mov      ax, current_month      ; get current month
              inc      ax                     ; number next month
              cmp      ax, 12                 ; same year?
              jna      @f                     ; yes, ok
              mov      ax, 1                  ; set to 1st month next
@@:           mov      bx, OFF month_of_year  ; address translate table
              xlat                            ; get offset to string
              add      bx, ax                 ; month string start addr
              @WinSetDlgItemText hwnd, ID_NEXT, ds:bx

              @return  0                      ; return


;  WM_COMMAND processing:
;     get window ID of command and select appropriate code
do_command:
              @route   <WPT mp1>,                                              \
                       ID_PREVIOUS, do_previous,                               \
                       ID_NEXT, do_next,                                       \
                       ID_ABOUT, do_about

              jmp      default                ; neither, do default


;  ID_PREVIOUS processing, update current month, year
do_previous:
              cmp      current_month, 1       ; first month of year?
              ja       @f                     ; no, skip
              cmp      current_year, 1901     ; current year 1901?
              je       do_previous_1          ; yes, can't go prior
              dec      current_year           ; previous year
              mov      current_month, 13      ; set 13th month!
@@:           dec      current_month          ; decrement to previous
              jmp      do_initdlg_1           ; send values to controls

do_previous_1:
              @return  0                      ; no change, return


;  ID_NEXT processing, update current month, year
do_next:
              cmp      current_month, 12      ; last month of year?
              jb       @f                     ; no, skip
              cmp      current_year, 2099     ; current year 2099?
              je       do_next_1              ; yes, can't go after
              inc      current_year           ; next year
              mov      current_month, 0       ; set 0th month!
@@:           inc      current_month          ; increment to next
              jmp      do_initdlg_1           ; send values to controls

do_next_1:
              @return  0                      ; no change, return


;  ID_ABOUT processing
do_about:
              @WinDlgBox HWND_DESKTOP, hwnd, about_proc, NULL,                 \
                       ID_ABOUTBOX, NULL

              @return  0


;  WM_CLOSE processing:
;     post WM_QUIT message to dialog window
do_close:
              @WinPostMsg hwnd, WM_QUIT, NULL, NULL

              @return  0                      ; return


window_proc   ENDP
              PAGE
;------------------------------------------------------------------------------
;  Dialog box procedure for About box
;------------------------------------------------------------------------------

about_proc    PROC     FAR,                                                    \
                       hwnd: DWORD, msg: WORD, mp1: DWORD, mp2: DWORD


;  Just default proccessing

              @WinDefDlgProc hwnd, msg, mp1, mp2

              ret


about_proc    ENDP
              PAGE
;------------------------------------------------------------------------------
;  Number conversion routines
;------------------------------------------------------------------------------

convert_num   PROC     NEAR USES ax


              aam                             ; split into two digits
              xchg     ah, al                 ; save second
              add      al, '0'                ; convert to ASCII
              stosb                           ; store digit at es:di
              xchg     ah, al                 ; restore second
              add      al, '0'                ; convert to ASCII
              stosb                           ; store digit at es:di

              ret                             ; return


convert_num   ENDP



convert_num_1 PROC     NEAR USES ax


              aam                             ; split into two digits
              or       ah, ah                 ; first digit zero?
              jz       @f                     ; yes, skip output

              xchg     ah, al                 ; save second
              add      al, '0'                ; convert to ASCII
              stosb                           ; store digit at es:di
              xchg     ah, al                 ; restore second

@@:           add      al, '0'                ; convert to ASCII
              stosb                           ; store digit at es:di

              ret                             ; return


convert_num_1 ENDP
              PAGE
              END      main



