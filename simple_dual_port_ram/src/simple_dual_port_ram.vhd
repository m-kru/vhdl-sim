-- SPDX-License-Identifier: MIT
-- https://github.com/m-kru/vhdl-sim
-- Copyright (c) 2022 Michał Kruszewski

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.ceil;
   use ieee.math_real.log2;

-- Simple_Dual_Port_RAM is a mock entity for simple dual port RAM.
--
-- READ_LATENCY - total port B read latency.
--
-- COMMON_CLOCK - false for asynchronous clocks. True if clka_i and clkb_i is actually the
-- same clock signal. The false value is the default value as this is worse case scenario.
-- For synchronous clocks, but with different frquencies or phases, there are 2 options:
--   1. Setting COMMON_CLOCK to true if you are sure there will be no timing violations
--      in the target design.
--   2. Setting COMMON_CLOCK to false, and setting appropriate value for DEAD_TIME if
--      you are not sure about timing violations in the target design.
--
-- DEAD_TIME - time for which the specific memory location must not be read after write
-- in case of asynchronous clocks. The actual datab_o value is (others => 'X').
--
-- INIT_VALUE - initial data value.
--
-- PREFIX - optional prefix used in report messages.
--
-- BLOCK_SIZE - size of the single allocated block. To optimize the memory usage the entity
-- internally uses access type. This generic may impact only simulator performance or memory
-- usage. It does not impact the functional behavior.
--
-- NOTE: Operating mode is not configurable and "READ FIRST" is assumed.
-- This is because in case of a collision and asynchronous clocks when port A writes
-- data to a memory location, then port B must not read  that location for a specified
-- amount of time. The operating mode is irrelevant in case of asynchronous clocks.
-- In case of a collision and synchronous clocks, a read operation on port B either produces data
-- (READ FIRST), or produces undefined data (Xs). For this reason, it is always advised to use
-- READ FIRST for blocks used in the target design. Make sure that the RAM component used
-- in the actual design has operating mode configured as READ FIRST.
entity Simple_Dual_Port_RAM is
   generic (
      WIDTH        : positive;
      DEPTH        : positive;
      READ_LATENCY : positive := 1;
      COMMON_CLOCK : boolean := false;
      DEAD_TIME    : time := 0 fs;
      INIT_VALUE   : std_logic_vector(WIDTH - 1 downto 0) := (others => 'U');
      PREFIX       : string := "";
      BLOCK_SIZE   : positive := 4096
   );
   port (
      -- Write port
      clka_i  : in std_logic;
      ena_i   : in std_logic := '1';
      addra_i : in unsigned(integer(ceil(log2(real(DEPTH)))) - 1 downto 0);
      dataa_i : in std_logic_vector(WIDTH - 1 downto 0);
      wea_i   : in std_logic;
      -- Read port
      clkb_i  : in  std_logic;
      enb_i   : in  std_logic := '1';
      addrb_i : in  unsigned(integer(ceil(log2(real(DEPTH)))) - 1 downto 0);
      datab_o : out std_logic_vector(WIDTH - 1 downto 0)
   );
begin

   assert COMMON_CLOCK or (DEAD_TIME > 0 fs)
      report "DEAD_TIME must be different than 0 in case of asynchronous clocks"
      severity failure;

end entity;


architecture Behavioral  of Simple_Dual_Port_RAM is

   constant BLOCK_COUNT : positive := integer(ceil(real(DEPTH) / real(BLOCK_SIZE)));

   impure function calc_last_block_size return positive is
      variable r : natural := DEPTH mod BLOCK_SIZE;
   begin
      if r = 0 then return BLOCK_SIZE; end if;
      return r;
   end function;
   constant LAST_BLOCK_SIZE : positive := calc_last_block_size;

   type t_block is array (0 to BLOCK_SIZE - 1) of std_logic_vector(WIDTH - 1 downto 0);
   type t_block_access is access t_block;
   type t_memory is array (0 to BLOCK_COUNT - 1) of t_block_access;

   constant ADDR_WIDTH : positive := integer(ceil(log2(real(DEPTH))));

   impure function blk_idx (addr : unsigned(ADDR_WIDTH - 1 downto 0)) return natural is
   begin
      return to_integer(addr) / BLOCK_SIZE;
   end function;

   impure function addr_in_blk (addr : unsigned(ADDR_WIDTH - 1 downto 0)) return natural is
   begin
      return to_integer(addr) mod BLOCK_SIZE;
   end function;

   type t_datab_latency_shift_reg is array (0 to READ_LATENCY - 1) of std_logic_vector(WIDTH - 1 downto 0);
   signal datab_latency_shift_reg : t_datab_latency_shift_reg := (others => INIT_VALUE);

begin

   process (clka_i, clkb_i) is
      variable mem : t_memory;

      variable blka, addra : natural;
      variable last_write_addr : unsigned(ADDR_WIDTH - 1 downto 0);
      variable last_write_time : time := 0 fs;

      variable blkb, addrb : natural;
   begin
      if rising_edge(clkb_i) then
         if enb_i = '1' then
            for i in 1 to READ_LATENCY - 1 loop
               datab_latency_shift_reg(i) <= datab_latency_shift_reg(i-1);
            end loop;

            blkb  := blk_idx(addrb_i);
            addrb := addr_in_blk(addrb_i);

            assert addrb_i < DEPTH
               report PREFIX & "cannot read address " & to_string(addrb_i) & " as the DEPTH is " & to_string(DEPTH)
               severity failure;

            if COMMON_CLOCK then
               if mem(blkb) = null then
                  datab_latency_shift_reg(0) <= INIT_VALUE;
               else
                  datab_latency_shift_reg(0) <= mem(blkb).all(addrb);
               end if;
            else
               if (now - last_write_time) < DEAD_TIME then
                  report PREFIX & "reading address " & to_string(addrb_i) & " during dead time"
                     severity error;
                  datab_latency_shift_reg(0) <= (others => 'X');
               elsif mem(blkb) = null then
                  datab_latency_shift_reg(0) <= INIT_VALUE;
               else
                  datab_latency_shift_reg(0) <= mem(blkb).all(addrb);
               end if;
            end if;
         end if;
      end if;

      if rising_edge(clka_i) then
         if ena_i = '1' then
            blka  := blk_idx(addra_i);
            addra := addr_in_blk(addra_i);

            if wea_i = '1' then
               assert addra_i < DEPTH
                  report PREFIX & "cannot write address " & to_string(addra_i) & " as the DEPTH is " & to_string(DEPTH)
                  severity failure;

               if mem(blka) = null then
                  mem(blka) := new t_block;
               end if;

               mem(blka).all(addra) := dataa_i;
               last_write_addr := addra_i;
               last_write_time := now;
            end if;
         end if;
      end if;
   end process;

   datab_o <= datab_latency_shift_reg(READ_LATENCY - 1);

end architecture;
