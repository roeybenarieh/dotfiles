/*
 * IdeaPad 5 15IIL05 (81YK), BIOS DPCN53WW ECDT override.
 * Correct GPE 6E -> 43 and increase OEM revision so Linux upgrades the table.
 * iasl calculates the table length and checksum when compiling this source.
 */

[000h 0000 004h]                   Signature : "ECDT"
[004h 0004 004h]                Table Length : 00000069
[008h 0008 001h]                    Revision : 01
[009h 0009 001h]                    Checksum : 00
[00Ah 0010 006h]                      Oem ID : "LENOVO"
[010h 0016 008h]                Oem Table ID : "CB-01   "
[018h 0024 004h]                Oem Revision : 00000002
[01Ch 0028 004h]             Asl Compiler ID : "    "
[020h 0032 004h]       Asl Compiler Revision : 01000013

[024h 0036 00Ch]     Command/Status Register : [Generic Address Structure]
[024h 0036 001h]                    Space ID : 01
[025h 0037 001h]                   Bit Width : 08
[026h 0038 001h]                  Bit Offset : 00
[027h 0039 001h]        Encoded Access Width : 00
[028h 0040 008h]                     Address : 0000000000000066

[030h 0048 00Ch]               Data Register : [Generic Address Structure]
[030h 0048 001h]                    Space ID : 01
[031h 0049 001h]                   Bit Width : 08
[032h 0050 001h]                  Bit Offset : 00
[033h 0051 001h]        Encoded Access Width : 00
[034h 0052 008h]                     Address : 0000000000000062

[03Ch 0060 004h]                         UID : 00000001
[040h 0064 001h]                  GPE Number : 43
[041h 0065 014h]                    Namepath : "\_SB.PCI0.LPCB.H_EC"
