// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

<%
  page_width = (cfg['pages_per_bank']-1).bit_length()
  bank_width = (cfg['banks']-1).bit_length()
  total_pages = cfg['banks']*cfg['pages_per_bank']
  bytes_per_page = cfg['words_per_page']*cfg['data_width'] / 8
  total_byte_width = int(total_pages*bytes_per_page-1).bit_length()
  info_type_width = (cfg['info_types']-1).bit_length()
%>

{ name: "FLASH_CTRL",
  clock_primary: "clk_i",
  other_clock_list: [ "clk_otp_i" ],
  reset_primary: "rst_ni",
  other_reset_list: [ "rst_otp_ni" ],
  bus_interfaces: [
    { protocol: "tlul", direction: "device" }
  ],
  available_input_list: [
    { name: "tck", desc: "jtag clock" },
    { name: "tms", desc: "jtag tms" },
    { name: "tdi", desc: "jtag input" },
  ],
  available_output_list: [
    { name: "tdo", desc: "jtag output" },
  ],
  interrupt_list: [
    { name: "prog_empty", desc: "Program FIFO empty" },
    { name: "prog_lvl",   desc: "Program FIFO drained to level" },
    { name: "rd_full",    desc: "Read FIFO full" },
    { name: "rd_lvl",     desc: "Read FIFO filled to level" },
    { name: "op_done",    desc: "Operation complete" },
  ],

  alert_list: [
    { name: "recov_err",
      desc: "flash alerts directly from prim_flash",
    },
    { name: "recov_mp_err",
      desc: "recoverable flash alert for permission error"
    },
    { name: "recov_ecc_err",
      desc: "recoverable flash alert for ecc error"
    },
  ],

  // Define flash_ctrl <-> flash_phy struct package
  inter_signal_list: [
    { struct:  "flash",          // flash_req_t, flash_rsp_t
      type:    "req_rsp",
      name:    "flash",          // flash_o (req), flash_i (rsp)
      act:     "req",
      package: "flash_ctrl_pkg", // Origin package (only needs for the requester)
    },

    { struct: "flash_otp_key",
      type: "req_rsp",
      name: "otp",
      act:  "req",
      package: "otp_ctrl_pkg"
    },

    { struct:  "lc_tx"
      type:    "uni"
      name:    "lc_creator_seed_sw_rw_en"
      act:     "rcv"
      package: "lc_ctrl_pkg"
    },

    { struct:  "lc_tx"
      type:    "uni"
      name:    "lc_owner_seed_sw_rw_en"
      act:     "rcv"
      package: "lc_ctrl_pkg"
    },

    { struct:  "lc_tx"
      type:    "uni"
      name:    "lc_iso_part_sw_rd_en"
      act:     "rcv"
      package: "lc_ctrl_pkg"
    },

    { struct:  "lc_tx"
      type:    "uni"
      name:    "lc_iso_part_sw_wr_en"
      act:     "rcv"
      package: "lc_ctrl_pkg"
    },

    { struct:  "lc_tx"
      type:    "uni"
      name:    "lc_seed_hw_rd_en"
      act:     "rcv"
      package: "lc_ctrl_pkg"
    }

    { struct:  "lc_tx"
      type:    "uni"
      name:    "rma_req"
      act:     "rcv"
      package: "lc_ctrl_pkg"
    },

    { struct:  "lc_tx"
      type:    "uni"
      name:    "rma_ack"
      act:     "req"
      package: "lc_ctrl_pkg"
    },

    { struct:  "lc_flash_rma_seed"
      type:    "uni"
      name:    "rma_seed"
      act:     "rcv"
      package: "lc_ctrl_pkg"
    },

    { struct: "pwr_flash",
      type: "req_rsp",
      name: "pwrmgr",
      act:  "rsp",
      package: "pwrmgr_pkg"
    },

    { struct: "keymgr_flash",
      type: "uni",
      name: "keymgr",
      act: "req",
      package: "flash_ctrl_pkg"
    }

  ],

  param_list: [
    // The reg parameters can be modified directly through top_*.hjson.
    // The template will automatically propagate the appropriate values.

    // Random netlist constants
    { name:      "RndCnstAddrKey",
      desc:      "Compile-time random bits for default address key",
      type:      "flash_ctrl_pkg::flash_key_t"
      randcount: "128",
      randtype:  "data", // randomize randcount databits
    },
    { name:      "RndCnstDataKey",
      desc:      "Compile-time random bits for default data key",
      type:      "flash_ctrl_pkg::flash_key_t"
      randcount: "128",
      randtype:  "data", // randomize randcount databits
    },
    { name:      "RndCnstLfsrSeed",
      desc:      "Compile-time random bits for initial LFSR seed",
      type:      "flash_ctrl_pkg::lfsr_seed_t"
      randcount: "32",
      randtype:  "data",
    },
    { name:      "RndCnstLfsrPerm",
      desc:      "Compile-time random permutation for LFSR output",
      type:      "flash_ctrl_pkg::lfsr_perm_t"
      randcount: "32",
      randtype:  "perm",
    },

    { name: "RegNumBanks",
      desc: "Number of flash banks",
      type: "int",
      default: "${cfg['banks']}",
      local: "true"
    },

    { name: "RegPagesPerBank",
      desc: "Number of pages per bank",
      type: "int",
      default: "${cfg['pages_per_bank']}",
      local: "true"
    },

    { name: "RegBusPgmResBytes",
      desc: "Number of pages per bank",
      type: "int",
      default: "${cfg['pgm_resolution_bytes']}",
      local: "true"
    },

    { name: "RegPageWidth",
      desc: "Number of bits needed to represent the pages within a bank",
      type: "int",
      default: "${page_width}",
      local: "true"
    },

    { name: "RegBankWidth",
      desc: "Number of bits needed to represent the number of banks",
      type: "int",
      default: "${bank_width}",
      local: "true"
    },

    { name: "NumRegions",
      desc: "Number of configurable flash regions",
      type: "int",
      default: "8",
      local: "true"
    },

    // The following parameters are derived from topgen and should not be
    // direclty modified.
    % for type in range(cfg['info_types']):
    { name: "NumInfos${type}",
      desc: "Number of configurable flash info pages for info type ${type}",
      type: "int",
      default: "${cfg['infos_per_bank'][type]}",
      local: "true"
    },
    % endfor

    { name: "WordsPerPage",
      desc: "Number of words per page",
      type: "int",
      default: "${cfg['words_per_page']}",
      local: "true"
    },

    { name: "BytesPerWord",
      desc: "Number of bytes per word",
      type: "int",
      default: "${cfg['data_width'] // 8}",
      local: "true"
    },

    { name: "BytesPerPage",
      desc: "Number of bytes per page",
      type: "int",
      default: "${cfg['data_width'] // 8 * cfg['words_per_page']}",
      local: "true"
    },

    { name: "BytesPerBank",
      desc: "Number of bytes per bank",
      type: "int",
      default: "${int(cfg['size'],0) // cfg['banks']}",
      local: "true"
    },




  ],

  regwidth: "32",
  registers: [

    { name: "CTRL_REGWEN",
      swaccess: "ro",
      hwaccess: "hwo",
      hwext: "true",
      desc: '''
      Controls the configurability of the !!CONTROL register.

      This register ensures the contents of !!CONTROL cannot be changed by software once a flash
      operation has begun.

      It unlocks whenever the existing flash operation completes, regardless of success or error.
      ''',

      fields: [
        { bits: "0",
          name: "EN",
          desc: '''
            Configuration enable.

            This bit defaults to 1 and is set to 0 by hardware when flash operation is initiated.
            When the controller completes the flash operation, this bit is set
            back to 1 to allow software configuration of !!CONTROL
          ''',
          resval: "1",
        },
      ]
      tags: [// This regwen is completely under HW management and thus cannot be manipulated
             // by software.
             "excl:CsrNonInitTests:CsrExclCheck"]
    },


    { name: "CONTROL",
      desc: "Control register",
      regwen: "CTRL_REGWEN",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0",
          hwaccess: "hrw",
          name: "START",
          desc: '''
            Start flash transaction.  This bit shall only be set after the other fields of the
            CONTROL register and ADDR have been programmed
            '''
          resval: "0"
          tags: [// Dont enable flash - it causes several side-effects.
                 "excl:CsrAllTests:CsrExclWrite"],
        },
        { bits: "5:4",
          name: "OP",
          desc: "Flash operation selection",
          resval: "0"
          enum: [
            { value: "0",
              name: "Read",
              desc: '''
                Flash Read.

                Read desired number of flash words
                '''
            },
            { value: "1",
              name: "Prog",
              desc: '''
                Flash Program.

                Program desired number of flash words
                '''
            },
            { value: "2",
              name: "Erase",
              desc: '''
                Flash Erase Operation.

                See ERASE_SEL for details on erase operation
                '''
            },
          ]
        },

        { bits: "6",
          name: "PROG_SEL",
          desc: "Flash program operation type selection",
          resval: "0"
          enum: [
            { value: "0",
              name: "Normal program",
              desc: '''
                Normal program operation to the flash
                '''
            },
            { value: "1",
              name: "Program repair",
              desc: '''
                Repair program operation to the flash.  Whether this is actually
                supported depends on the underlying flash memory.
                '''
            },
          ]
        },

        { bits: "7",
          name: "ERASE_SEL",
          desc: "Flash erase operation type selection",
          resval: "0"
          enum: [
            { value: "0",
              name: "Page Erase",
              desc: '''
                Erase 1 page of flash
                '''
            },
            { value: "1",
              name: "Bank Erase",
              desc: '''
                Erase 1 bank of flash
                '''
            },
          ]
        },
        { bits: "8",
          name: "PARTITION_SEL",
          desc: '''
            Selects either info or data partition for operation.

            When 0, select data partition - this is the portion of flash that is accessible both
            by the host and by the controller.

            When 1, select info partition - this is the portion of flash that is only accessible
            by the controller.

          '''
          resval: "0"
        },
        { bits: "${9 + info_type_width -1}:9",
          name: "INFO_SEL",
          desc: '''
            Informational partions can have multiple types.

            This field selects the info type to be accessed.
          '''
          resval: "0"
        },
        { bits: "27:16",
          name: "NUM",
          desc: "Number of bus words the flash operation should read or program.",
          resval: "0"
        },
      ]
    },
    { name: "ADDR",
      desc: "Address for flash operation",
      swaccess: "rw",
      hwaccess: "hro",
      resval: "0",
      fields: [
        { bits: "31:0",
          name: "START",
          desc: '''
            Start address of a flash transaction.  Software should supply the full byte address.
            The flash controller will then truncate the address as needed.  For read operations,
            the flash controller will truncate to the closest, lower word aligned address.  For
            example, if 0x13 is supplied, the controller will perform a read at address 0x10.

            Program operations behave similarly, the controller does not have read modified write
            support.

            For page erases, the controller will truncate to the closest lower page aligned
            address.  Similarly for bank erases, the controller will truncate to the closest
            lower bank aligned address.
            '''
          resval: "0"
        },
      ]
    },

    // Program type
    { name: "PROG_TYPE_EN",
      desc: "Enable different program types",
      swaccess: "rw0c",
      hwaccess: "hro",
      fields: [
        { bits: "0",
          resval: "1",
          name: "NORMAL",
          desc: '''
            Normal prog type available
            '''
        },
        { bits: "1",
          resval: "1",
          name: "REPAIR",
          desc: '''
            Repair prog type available
            '''
        },
      ]
    },

    // erase suspend support
    { name: "ERASE_SUSPEND",
      desc: "Suspend erase",
      swaccess: "rw",
      hwaccess: "hrw",
      fields: [
        { bits: "0",
          resval: "0",
          name: "REQ",
          desc: '''
            When 1, request erase suspend.
            If no erase ongoing, the request is immediately cleared by hardware
            If erase ongoing, the request is fed to the flash_phy and cleared when the suspend is handled.
            '''
        },
      ],
      tags: [// Erase suspend must be directly tested
        "excl:CsrAllTests:CsrExclWrite"],
    },

    // Data partition memory properties region setup
    { multireg: {
        cname: "FLASH_CTRL",
        name: "REGION_CFG_REGWEN"
        desc: "Memory region registers configuration enable.",
        count: "NumRegions",
        swaccess: "rw0c",
        hwaccess: "none",
        compact: false,
        fields: [
            { bits: "0",
              name: "REGION",
              resval: "1"
              desc: "Region register write enable.  Once set to 0, it can longer be configured to 1",
              enum: [
                { value: "0",
                  name: "Region locked",
                  desc: '''
                    Region can no longer be configured until next reset
                    '''
                },
                { value: "1",
                  name: "Region enabled",
                  desc: '''
                    Region can be configured
                    '''
                },
              ]
            },
        ],
      },
    },

    { multireg: {
        cname: "FLASH_CTRL",
        name: "MP_REGION_CFG",
        desc: "Memory property configuration for data partition",
        count: "NumRegions",
        swaccess: "rw",
        hwaccess: "hro",
        regwen: "REGION_CFG_REGWEN",
        regwen_multi: true,
        fields: [
            { bits: "0",
              name: "EN",
              desc: '''
                Region enabled, following fields apply
              ''',
              resval: "0"
            },
            { bits: "1",
              name: "RD_EN",
              desc: '''
                Region can be read
              ''',
              resval: "0"
            },
            { bits: "2",
              name: "PROG_EN",
              desc: '''
                Region can be programmed
              ''',
              resval: "0"
            }
            { bits: "3",
              name: "ERASE_EN",
              desc: '''
                Region can be erased
              ''',
              resval: "0"
            }
            { bits: "4",
              name: "SCRAMBLE_EN",
              desc: '''
                Region is scramble enabled.
              ''',
              resval: "0"
            }
            { bits: "5",
              name: "ECC_EN",
              desc: '''
                Region is ECC enabled.
              ''',
              resval: "0"
            }
            { bits: "6",
              name: "HE_EN",
              desc: '''
                Region is high endurance enabled.
              ''',
              resval: "0"
            }
            { bits: "${8 + bank_width + page_width - 1}:8",
              name: "BASE",
              desc: '''
                Region base page. Note the granularity is page, not byte or word
              ''',
              resval: "0"
            },
            { bits: "${8 + 2*bank_width + 2*page_width}:${8 + bank_width + page_width}",
              name: "SIZE",
              desc: '''
                Region size in number of pages
              ''',
              resval: "0"
            },
        ],
      },
    },

    // Default region properties for data partition
    { name: "DEFAULT_REGION",
      desc: "Default region properties",
      swaccess: "rw",
      hwaccess: "hro",
      resval: "0",
      fields: [
        { bits: "0",
          name: "RD_EN",
          desc: '''
            Region can be read
          ''',
          resval: "0"
        },
        { bits: "1",
          name: "PROG_EN",
          desc: '''
            Region can be programmed
          ''',
          resval: "0"
        }
        { bits: "2",
          name: "ERASE_EN",
          desc: '''
            Region can be erased
          ''',
          resval: "0"
        },
        { bits: "3",
          name: "SCRAMBLE_EN",
          desc: '''
            Region is scrambleenabled
          ''',
          resval: "0"
        }
        { bits: "4",
          name: "ECC_EN",
          desc: '''
            Region is ECC enabled
          ''',
          resval: "0"
        }
        { bits: "5",
          name: "HE_EN",
          desc: '''
            Region is high endurance enabled
          ''',
          resval: "0"
        }
      ]
    },

    // Info partition memory properties setup
    % for bank in range(cfg['banks']):
    %   for idx in range(cfg['info_types']):
    { multireg: {
        cname: "FLASH_CTRL",
        name: "BANK${bank}_INFO${idx}_REGWEN"
        desc: "Memory region registers configuration enable.",
        count: "NumInfos${idx}",
        swaccess: "rw0c",
        hwaccess: "none",
        compact: false,
        fields: [
            { bits: "0",
              name: "REGION",
              resval: "1"
              desc: "Info${idx} page write enable.  Once set to 0, it can longer be configured to 1",
              enum: [
                { value: "0",
                  name: "Page locked",
                  desc: '''
                    Region can no longer be configured until next reset
                    '''
                },
                { value: "1",
                  name: "Page enabled",
                  desc: '''
                    Region can be configured
                    '''
                },
              ]
            },
        ],
      },
    },

    { multireg: {
        cname: "FLASH_CTRL",
        name: "BANK${bank}_INFO${idx}_PAGE_CFG",
        desc: '''
                Memory property configuration for info partition in bank${bank},
                Unlike data partition, each page is individually configured.
              '''
        count: "NumInfos${idx}",
        swaccess: "rw",
        hwaccess: "hro",
        regwen: "BANK${bank}_INFO${idx}_REGWEN",
        regwen_multi: true,
        fields: [
            { bits: "0",
              name: "EN",
              desc: '''
                Region enabled, following fields apply
              ''',
              resval: "0"
            },
            { bits: "1",
              name: "RD_EN",
              desc: '''
                Region can be read
              ''',
              resval: "0"
            },
            { bits: "2",
              name: "PROG_EN",
              desc: '''
                Region can be programmed
              ''',
              resval: "0"
            }
            { bits: "3",
              name: "ERASE_EN",
              desc: '''
                Region can be erased
              ''',
              resval: "0"
            }
            { bits: "4",
              name: "SCRAMBLE_EN",
              desc: '''
                Region is scramble enabled.
              ''',
              resval: "0"
            }
            { bits: "5",
              name: "ECC_EN",
              desc: '''
                Region is ECC enabled.
              ''',
              resval: "0"
            }
            { bits: "6",
              name: "HE_EN",
              desc: '''
                Region is high endurance enabled.
              ''',
              resval: "0"
            }
        ],
      },
    },
    %   endfor
    % endfor

    { name: "BANK_CFG_REGWEN"
      desc: "Bank configuration registers configuration enable.",
      swaccess: "rw0c",
      hwaccess: "none",
      fields: [
          { bits: "0",
            name: "BANK",
            resval: "1"
            desc: "Bank register write enable.  Once set to 0, it can longer be configured to 1",
            enum: [
              { value: "0",
                name: "Bank locked",
                desc: '''
                  Bank can no longer be configured until next reset
                  '''
              },
              { value: "1",
                name: "Bank enabled",
                desc: '''
                  Bank can be configured
                  '''
              },
            ]
          },
      ],
    },

    { multireg: {
        cname: "FLASH_CTRL",
        name: "MP_BANK_CFG",
        desc: "Memory properties bank configuration",
        count: "RegNumBanks",
        swaccess: "rw",
        hwaccess: "hro",
        regwen: "BANK_CFG_REGWEN"
        fields: [
            { bits: "0",
              name: "ERASE_EN",
              desc: '''
                Bank wide erase enable
              ''',
              resval: "0"
            },
        ],
      },
    },

    { name: "OP_STATUS",
      desc: "Flash Operation Status",
      swaccess: "rw",
      hwaccess: "hwo",
      fields: [
        { bits: "0", name: "done",
          desc: "Flash operation done. Set by HW, cleared by SW" },
        { bits: "1", name: "err",
          desc: "Flash operation error. Set by HW, cleared by SW. See !!ERR_CODE for more details."},
      ]
    },

    { name: "STATUS",
      desc: "Flash Controller Status",
      swaccess: "ro",
      hwaccess: "hwo",
      fields: [
        { bits: "0",    name: "rd_full",    desc: "Flash read FIFO full, software must consume data"},
        { bits: "1",    name: "rd_empty",   desc: "Flash read FIFO empty", resval: "1"},
        { bits: "2",    name: "prog_full",  desc: "Flash program FIFO full"},
        { bits: "3",    name: "prog_empty", desc: "Flash program FIFO empty, software must provide data", resval: "1"},
        { bits: "4",    name: "init_wip",   desc: "Flash controller undergoing init, inclusive of phy init"},
      ]
    },

    { name: "ERR_CODE",
      desc: '''
        Flash error code register.
        This register tabulates detailed error status of the flash.
        This is separate from !!OP_STATUS, which is used to indicate the current state of the software initiated
        flash operation.
      '''
      swaccess: "rw",
      hwaccess: "hwo",
      fields: [
        { bits: "0",
          name: "flash_err",
          desc: '''
            The flash memory itself has an error, please check the vendor specs for details of the error.
          '''
        },
        { bits: "1",
          name: "flash_alert",
          desc: '''
            The flash memory itself has triggered an alert, please check the vendor specs for details of the error.
          '''
        },
        { bits: "2",
          name: "mp_err",
          desc: '''
            Flash access has encountered an access permission error.
            Please see !!ERR_ADDR for exact address.
          '''
        },
        { bits: "3",
          name: "ecc_single_err",
          desc: '''
            Flash access has encountered a single bit ECC error.
            Please see !!ECC_ERR_ADDR for exact address.
          '''
        },
        { bits: "4",
          name: "ecc_multi_err",
          desc: '''
            Flash access has encountered a multi bit ECC error.
            Please see !!ECC_ERR_ADDR for exact address.
          '''
        },
      ]
    },

    { name: "ERR_ADDR",
      desc: "Access permission error address",
      swaccess: "ro",
      hwaccess: "hwo",
      fields: [
        { bits: "${bank_width + page_width -1}:0",
          resval: 0,
        },
      ]
    },

    { multireg: {
        cname: "ECC_ERR"
        name: "ECC_ERR_ADDR",
        desc: "ecc error address",
        count: "RegNumBanks",
        swaccess: "ro",
        hwaccess: "hwo",
        fields: [
          { bits: "${total_byte_width-1}:0",
            resval: 0,
          },
        ]
      }
    },

    { name: "PHY_ALERT_CFG",
      desc: "Phy alert configuration",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "0",
          name: "alert_ack",
          desc: "Acknowledge flash phy alert"
        },
        { bits: "1",
          name: "alert_trig",
          desc: "Trigger flash phy alert"
        }
      ]
      tags: [ // alert triggers should be tested by directed tests
             "excl:CsrAllTests:CsrExclWrite"]
    },

    { name: "PHY_STATUS",
      desc: "Flash Phy Status",
      swaccess: "ro",
      hwaccess: "hwo",
      fields: [
        { bits: "0",
          name: "init_wip",
          desc: "Flash phy controller initializing"
        },
        { bits: "1",
          name: "prog_normal_avail",
          resval: "0x1",
          desc: "Normal program supported"
        },
        { bits: "2",
          name: "prog_repair_avail",
          resval: "0x1",
          desc: "Program repair supported"
        },
      ]
    },

    { name: "Scratch",
      desc: "Flash Controller Scratch",
      swaccess: "rw",
      fields: [
        { bits: "31:0", name: "data",  desc: "Flash ctrl scratch register" },
      ]
    },
    { name: "FIFO_LVL",
      desc: "Programmable depth where FIFOs should generate interrupts",
      swaccess: "rw",
      hwaccess: "hro",
      fields: [
        { bits: "4:0",
          name: "PROG",
          desc: '''
            When the program FIFO drains to this level, trigger an interrupt.
            Default value is set such that interrupt does not trigger at reset.
            '''
          resval: "0xF"
        },
        { bits: "12:8",
          name: "RD",
          desc: '''
            When the read FIFO fills to this level, trigger an interrupt.
            Default value is set such that interrupt does not trigger at reset.
            '''
          resval: "0xF"
        },
      ]
    }

    { name: "FIFO_RST",
      desc: "Reset for flash controller FIFOs",
      swaccess: "rw",
      hwaccess: "hro",
      resval: "0",
      fields: [
        { bits: "0",
          name: "EN",
          desc: '''
            Active high resets for both program and read FIFOs.  This is especially useful after the controller
            encounters an error of some kind.

            This bit will hold the FIFO in reset as long as it is set.
            '''
          resval: "0"
        },
      ]
    },

    { window: {
        name: "prog_fifo",
        items: "1",
        validbits: "32",
        byte-write: "false",
        unusual: "false"
        swaccess: "wo",
        desc: '''
          Flash program FIFO.

          The FIFO is 16 entries of 4B flash words. This FIFO can only be programmed
          by software after a program operation has been initiated via the !!CONTROL register.
          This ensures accidental programming of the program FIFO cannot lock up the system.
          '''
      },
    },

    { window: {
        name: "rd_fifo",
        items: "1",
        validbits: "32",
        byte-write: "false",
        unusual: "false"
        swaccess: "ro",
        desc: '''
          Flash read FIFO.

          The FIFO is 16 entries of 4B flash words
          '''
      },
    },

    { window: {
        name: "prim_flash_cfg",
        items: "21",
        validbits: "32",
        byte-write: "true",
        // Setting the unusual flag avoids warning messages from regtool about
        // the unusual number of items in the window.
        unusual: "true"
        swaccess: "rw",
        desc: '''
          Configuration window for prim_flash.

          This window contains proprietary registers that is not exposed in open-source.
          '''
      },
    },
  ]
}
