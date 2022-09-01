library ieee;
   use ieee.std_logic_1164.all;

-- Simple_PLL is a mock entity for MMCM/PLL with following assumptions:
--   1. input clock is ideal (has not jitter),
-- and following predefined configuration:
--   1. output clocks startup is always safe,
--   2. no dynamic reconfiguration,
--   3. no reset port as there is no dynamic reconfiguration,
--   4. duty cycle is always 50 %.
-- Simulating lock loss can be achieved with proper driving of clk_i and LOSS_TIME generic value.
-- In such case LOSS_SVRITY must be set correctly to not cause simulation failure.
--
-- Clocks are specified with periods, not frequencies, because seconds_to_time() function has been introduced in VHDL 2019,
-- and support for this revision was still poor during development.
--
-- IN_PERIOD - input clock period.
-- LOCK_TIME - period of time for which the input clock must be stable (clk_i period = IN_PERIOD).
-- LOSS_TIME - period of time in which at least one rising edge of clk_i must appear or Simple_PLL will lose lock.
--
-- CLOCK_COUNT - number of output clocks.
-- OUT_PERIODS - periods of output clocks.
-- OUT_PHASES  - phases of output clocks relative to the first rising edge of clk_i after lock.
--
-- LOSS_SVRITY - severity of report message when lock is lost.
-- PREFIX      - optional prefix used in report messages.
--
-- If input clock period differs from IN_PERIOD then warning is reported.
entity Simple_PLL is
   generic (
      -- Input clock generics.
      IN_PERIOD : time;
      LOCK_TIME : time := 8 * IN_PERIOD;
      LOSS_TIME : time := IN_PERIOD + 1 fs;

      -- Output clocks generics.
      CLOCK_COUNT : positive := 1;
      OUT_PERIODS : time_vector(0 to CLOCK_COUNT - 1);
      OUT_PHASES  : time_vector(0 to CLOCK_COUNT - 1) := (others => 0 ns);

      LOSS_SVRITY : severity_level := failure;
      PREFIX      : string := ""
   );
   port (
      clk_i    : in  std_logic;
      clks_o   : out std_logic_vector(CLOCK_COUNT - 1 downto 0);
      locked_o : out std_logic
   );
end entity;


architecture Behavioral of Simple_PLL is

   constant PERIOD_WAIT_TIME : time := IN_PERIOD + 1 fs;

   signal locked : std_logic := '0';

begin

   locked_o <= locked;


   input_clk_monitor : process
      variable prev_rising_edge : time := 0 ns;
      variable stable_time : time := 0 ns;
      variable delta : time := 0 ns;

      variable wait_time : time := PERIOD_WAIT_TIME;

      procedure check_period is begin
         -- Ignore first rising edge during simulation startup or after lock loss.
         if prev_rising_edge = 0 fs then
            return;
         end if;

         if delta /= IN_PERIOD then
            report PREFIX & "clk_i period equals " & to_string(delta) &
               ", expecting " & to_string(IN_PERIOD)
               severity warning;
         end if;
      end procedure;

   begin
      wait until rising_edge(clk_i) for wait_time;

      if locked then
         if rising_edge(clk_i) then
            delta := now - prev_rising_edge;
            check_period;
            prev_rising_edge := now;
         else
            locked <= '0';
            wait_time := PERIOD_WAIT_TIME;
            prev_rising_edge := 0 ns;
            report PREFIX & "lock lost, no clk_i rising edge for " & to_string(LOSS_TIME) severity LOSS_SVRITY;
         end if;
      else
         if rising_edge(clk_i) then
            delta := now - prev_rising_edge;
            check_period;
            prev_rising_edge := now;

            if delta = IN_PERIOD then
               stable_time := stable_time + delta;
            else
               stable_time := 0 ns;
            end if;

            if stable_time > LOCK_TIME then
               locked <= '1';
               wait_time := LOSS_TIME;
               report PREFIX & "lock acquired";
            end if;
         end if;
      end if;
   end process;


   output_clocks : for o in 0 to CLOCK_COUNT - 1 generate

      process is
      begin
         wait until locked;
         wait for OUT_PHASES(o);
         loop
            clks_o(o) <= '1';
            wait for OUT_PERIODS(o) / 2;
            clks_o(o) <= '0';
            wait for OUT_PERIODS(o) / 2;
            exit when not locked;
         end loop;
      end process;

   end generate;

end architecture;
