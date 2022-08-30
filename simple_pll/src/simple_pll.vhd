library ieee;
   use ieee.std_logic_1164.all;

-- Simple_PLL is a mock entity for MMCM/PLL with following predefined configuration:
--   1. clocks startup is always safe,
--   2. no dynamic reconfiguration,
--   3. no reset port as there is no dynamic reconfiguration,
--   4. duty cycle is always 50 %.
-- Simulating lock loss can be achieved with proper driving of clk_i and INPUT_PERIOD_TOLERANCE generic value.
-- In such case LOCK_LOST_SEVERITY must be set correctly to not cause simulation failure.
--
-- Clocks are specified with periods, not frequencies, because seconds_to_time() function has been introduced in VHDL 2019,
-- and support for this revision was still poor during development.
--
-- clk_i must be stable for more than the LOCK_TIME (starting from the rising edge) to allow Simple_PLL to acquire the lock.
--
-- INPUT_PERIOD - input clock period.
--
-- INPUT_PERIOD_TOLERANCE - allowed variation of clk_i period.
-- It must not be set to 0, as the entity will not work correctly.
--
-- LOCK_TIME - period of time for which the input clock must be stable (clk_i period <= INPUT_PERIOD + INPUT_PERIOD_TOLERANCE).
--
-- CLOCKS_COUNT - number of output clocks.
--
-- OUTPUT_PERIODS - periods of output clocks.
--
-- OUTPUT_PHASES - phases of output clocks relative to input clock.
--
-- LOCK_LOST_SEVERITY - severity of report message when lock is lost.
--
-- PREFIX - optional prefix used in report messages.
--
-- NOTE: INPUT_PERIOD_TOLERANCE affects only lock mechanism.
-- It does not impact the output frequencies, that are _always_ reciprocal of OUTPUT_PERIODS.
entity Simple_PLL is
   generic (
      -- Input clock generics.
      INPUT_PERIOD           : time;
      INPUT_PERIOD_TOLERANCE : time := 1 fs;
      LOCK_TIME              : time := 8 * INPUT_PERIOD;

      -- Output clocks generics.
      CLOCKS_COUNT   : positive := 1;
      OUTPUT_PERIODS : time_vector(0 to CLOCKS_COUNT - 1);
      OUTPUT_PHASES  : time_vector(0 to CLOCKS_COUNT - 1) := (others => 0 ns);

      LOCK_LOST_SEVERITY : severity_level := failure;
      PREFIX             : string := ""
   );
   port (
      clk_i    : in  std_logic;
      clks_o   : out std_logic_vector(CLOCKS_COUNT - 1 downto 0);
      locked_o : out std_logic
   );
end entity;


architecture Behavioral of Simple_PLL is

   signal locked : std_logic := '0';

begin

   locked_o <= locked;


   input_clk_monitor : process
      variable prev_clk_rising_edge : time := 0 ns;
      variable clk_stable_time : time := 0 ns;
      variable delta : time := 0 ns;
   begin
      wait until rising_edge(clk_i) for INPUT_PERIOD + INPUT_PERIOD_TOLERANCE;

      if locked = '1' then
         if not rising_edge(clk_i) then
            locked <= '0';
            report PREFIX & "lock lost" severity LOCK_LOST_SEVERITY;
         end if;
      else
         if rising_edge(clk_i) then
            delta := now - prev_clk_rising_edge;
            if delta <= INPUT_PERIOD + INPUT_PERIOD_TOLERANCE then
               clk_stable_time := clk_stable_time + delta;
            else
               clk_stable_time := 0 ns;
            end if;
            prev_clk_rising_edge := now;

            if clk_stable_time > LOCK_TIME then
               locked <= '1';
               report PREFIX & "lock acquired";
            end if;
         end if;
      end if;
   end process;


   output_clocks : for o in 0 to CLOCKS_COUNT - 1 generate

      process is
      begin
         loop
            wait until locked;
            wait for OUTPUT_PHASES(o);
            loop
               clks_o(o) <= '1';
               wait for OUTPUT_PERIODS(o) / 2;
               clks_o(o) <= '0';
               wait for OUTPUT_PERIODS(o) / 2;
               exit when not locked;
            end loop;
         end loop;
      end process;

   end generate;

end architecture;
