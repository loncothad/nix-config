{ config, lib, ... }:

with lib;

let
  cfg = config.boot.mitigations;
in
{
  options = {
    boot.mitigations = {
      global = {
        disable = mkOption {
          type = types.bool;
          default = false;
          description = "Disable all core CPU transient execution side-channel mitigations globally.";
        };
      };
      spectre = {
        disable = mkOption {
          type = types.bool;
          default = false;
          description = "Disable Spectre Variant 1, Variant 2, and Speculative Store Bypass mitigations.";
        };
      };
      meltdown = {
        disable = mkOption {
          type = types.bool;
          default = false;
          description = "Disable Meltdown / Page Table Isolation (PTI).";
        };
      };
      mdsL1tf = {
        disable = mkOption {
          type = types.bool;
          default = false;
          description = "Disable Microarchitectural Data Sampling (MDS) and L1 Terminal Fault (L1TF) mitigations.";
        };
      };
      tsx = {
        disable = mkOption {
          type = types.bool;
          default = false;
          description = "Disable TSX Async Abort (TAA) mitigations (forces TSX execution on).";
        };
      };
      modernLeaks = {
        disable = mkOption {
          type = types.bool;
          default = false;
          description = "Disable modern sampling mitigations (Retbleed, Downfall, SRBDS, MMIO, Inception, RFDS).";
        };
      };
    };
  };

  config = {
    boot.kernelParams = mkMerge [
      # CRITICAL SEVERITY: Disables all software/hardware mitigation vectors completely.
      (mkIf cfg.global.disable [ "mitigations=off" ])

      # HIGH SEVERITY: Disables branch prediction and speculation barriers.
      (mkIf cfg.spectre.disable [
        "nospectre_v1"
        "nospectre_v2"
        "spectre_v2=off"
        "nospec_store_bypass_disable"
        "spec_store_bypass_disable=off"
        "noibpb"
        "noibrs"
        "no_stf_barrier"
      ])

      # HIGH SEVERITY: Disables Page Table Isolation (PTI).
      (mkIf cfg.meltdown.disable [
        "nopti"
        "pti=off"
      ])

      # HIGH SEVERITY: Disables hardware tracking/clearing of LFB, Load/Store buffers.
      (mkIf cfg.mdsL1tf.disable [
        "mds=off"
        "l1tf=off"
      ])

      # MEDIUM SEVERITY: Re-enables hardware TSX transaction processing.
      (mkIf cfg.tsx.disable [
        "tsx=on"
        "tsx_async_abort=off"
      ])

      # HIGH SEVERITY: Disables protection against modern structural execution leaks.
      (mkIf cfg.modernLeaks.disable [
        "srbds=off"
        "mmio_stale_data=off"
        "retbleed=off"
        "gather_data_sampling=off"
        "gds=off"
        "spec_rstack_overflow=off"
        "reg_file_data_sampling=off"
        "kvm.mitigate_smt_rsb=0"
      ])
    ];
  };
}
