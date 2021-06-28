#!/usr/bin/env python3
import os, sys
import yaml


files = [
    (["axi_slice"      ], "axi/axi_slice/src_files.yml"),
    (["axi_slice_dc"   ], "axi/axi_slice_dc/src_files.yml"),
    (["axi_node"       ], "axi/axi_node/src_files.yml"),
    (["adv_dbg_if"     ],"adv_dbg_if/src_files.yml"),
    (["axi_mem_if_DP"  ],"axi/axi_mem_if_DP/src_files.yml"),
    (["apb_gpio"       ],"apb/apb_gpio/src_files.yml"),
    (["apb_pulpino"    ],"apb/apb_pulpino/src_files.yml"),
    (["apb_node"       ],"apb/apb_node/src_files.yml"),
    (["apb_i2c"        ],"apb/apb_i2c/src_files.yml"),
    (["apb_uart_sv"    ],"apb/apb_uart_sv/src_files.yml"),
    (["apb_timer"      ],"apb/apb_timer/src_files.yml"),
    (["apb_event_unit" ],"apb/apb_event_unit/src_files.yml"),
    (["apb_uart"       ],"apb/apb_uart/src_files.yml"),
    (["apb_fll_if"     ],"apb/apb_fll_if/src_files.yml"),
    (["apb_spi_master" ],"apb/apb_spi_master/src_files.yml"),
    (["apb2per"        ],"apb/apb2per/src_files.yml"),
    (["axi2apb"        ],"axi/axi2apb/src_files.yml"),
    (["core2axi"       ],"axi/core2axi/src_files.yml"),
    (["axi_spi_slave"  ],"axi/axi_spi_slave/src_files.yml"),
    (["zeroriscy", "zeroriscy_regfile_rtl" ],"zero-riscy/src_files.yml"),
]

def open_yaml(path):
    with open(path, 'r') as f:
        try:
            return yaml.safe_load(f)
        except yaml.YAMLError as exc:
            print(exc)


def main():
    if (len(sys.argv) != 2):
        print("Error: Only 1 arg allowed")
        sys.exit(1)

    prefix = sys.argv[1]
    real_path = [(i, prefix + p) for (i, p) in files]
    for (names,p) in real_path:
        if os.path.isfile(p):
            yaml = open_yaml(p)
            path_prefix = os.path.dirname(p)
            for name in names:
                for rtl in yaml[name]['files']:
                    sys.stdout.write(" {} ".format(os.path.join(path_prefix, rtl)))
main()
