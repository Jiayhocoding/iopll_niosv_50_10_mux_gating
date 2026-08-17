// (C) 2001-2026 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10034 10035 10036 10037 10230 10240 10030 

module altera_avalon_sysid_qsys #(
    parameter USE_MANUAL_ID = 1,
    parameter MANUAL_ID = 1,
    parameter HASH_ID = 1,
    parameter TIMESTAMP = 1
)(
    // inputs:
     address,
     clock,
     reset_n,
    
    // outputs:
     readdata
)
;

  output  [ 31: 0] readdata;
  input            address;
  input            clock;
  input            reset_n;

  wire    [ 31: 0] readdata /* synthesis keep */;
  
  //control_slave, which is an e_avalon_slave
  assign readdata = address ? TIMESTAMP : ( USE_MANUAL_ID ? MANUAL_ID : HASH_ID );

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "fs3MoWBgHCF39POOsRTSk9Of235Syebg6gnxSRl1C3eH9/q9SvVYcuvHV6n+ciNcw1ZgnLUuBtqkgc5BFhhjFnxbTVeuzHhPTudkRx35Y+NfPOUkDAugUZPKer0wXL9pRAwH3byzjlgXB2SHOxqIBOiiFdHFMWEzFqqitQSeTR0XsgNSEUtkjewHkaIdmB+gUPZtp91aSbp/tszSUSGSEr2Yzzd/T421QZLUt8TjkSAX3MiQzLCld5uc3gusaASxJs8EiAqtYMG8WvSbz+XbYuGuQ2BxoSO4PQReiAxvTYahcR/B7r5Hb25X20wxnje6FXwJLddEfpRCXQewdtHHOV8C8p3u8JJGR/hmRrH2nvkNtUdlSgIWeux0NHfYnd64bzu3Y+/2IWgGgYSKvSj5yIFz+5stifj0nJDt+OeF7mCTZMmYCHeFIIB3MGzW0i0d6zVOmZsKUXRMfhKSwyak5qvQ4vTdo+4kf/B/aUUX1i06puA8GMo2qxUDRbdF6DikdeRFV0zetxOvQBdapdyAm72WQmH9WkKnQUnbtBAqktPybox5syEUX6br/91mObR7PwMaYeHSipwiEVGkNEazGsgfiZfhzTeaEYC4ScHRG9nyFsZ71G93NQiYNV0UEaJ8jetWsmiEzG6HB45K5Syt92jAz1qZSCSRUO394886nPPPHGmqx6BLgYWylmZtFEyhLBjV6ltEHdejtAd50hN1cHEOnW811j2TfgU17EARwWukr6NVpEXyd5sDScpo3WaWbYdalFRhgVH2dRGe1cFTKHBV2Lh56GzLFM6VUm0n0bk7Ksli+ah7Lpk7fwzrACVh+UsjK0zxjEXMROzjKeKm+ZMdHFUnnBDjE/NnJBgs83sdJW3gZLkjTnevn1jumrmCYQtucdMSueNkkSjlmRTkkEozvKJcjm/WV38+W6yBPpRUZ4w72K3/plbJqSCp6uURb3ldgksghBQziyGsSuME/FTf1QxFk/6TwM+uvjJsCsSpqpuQdoyinGD+tHEVSLqh"
`endif