library ieee;
   use ieee.std_logic_1164.all;

library sim;


entity tb_simple_pll is
end entity;


architecture test of tb_simple_pll is

   constant IN_CLK_PERIOD : time := 10 ns;
   signal in_clk : std_logic := '0';

   signal out_clk_0, out_clk_1 : std_logic;
   signal locked : std_logic;

begin

   in_clk_driver : process is
   begin
      for i in 0 to 20 loop
         in_clk <= '1';
         wait for IN_CLK_PERIOD / 2;
         in_clk <= '0';
         wait for IN_CLK_PERIOD / 2;
      end loop;
      wait for 100 ns;
      for i in 0 to 20 loop
         in_clk <= '1';
         wait for IN_CLK_PERIOD / 2;
         in_clk <= '0';
         wait for IN_CLK_PERIOD / 2;
      end loop;
   end process;


   DUT : entity sim.Simple_PLL
   generic map (
      IN_PERIOD   => IN_CLK_PERIOD,
      LOCK_TIME   => 40 ns,
      CLOCK_COUNT => 2,
      OUT_PERIODS => (IN_CLK_PERIOD, 4 * IN_CLK_PERIOD),
      OUT_PHASES  => (2.5 ns, 5 ns),
      LOSS_SVRITY => ERROR,
      PREFIX      => "sim PLL: "
   ) port map (
      clk_i     => in_clk,
      clks_o(0) => out_clk_0,
      clks_o(1) => out_clk_1,
      locked_o  => locked
   );


   main : process is
   begin
      wait for 50 * IN_CLK_PERIOD;
      std.env.finish;
   end process;

end architecture;
