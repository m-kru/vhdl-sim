library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

library sim;


entity tb_simple_dual_port_ram_dead_time is
end entity;

architecture test of tb_simple_dual_port_ram_dead_time is

   constant WIDTH : positive := 8;
   constant DEPTH : positive := 128;
   constant ADDR_WIDTH : positive := 7;
   constant DEAD_TIME  : time := 5 ns;

   constant CLKA_PERIOD : time := 9 ns;
   signal clka : std_logic := '0';

   constant CLKB_PERIOD : time := 10 ns;
   signal clkB : std_logic := '0';

   signal addra, addrb : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
   signal dataa, datab : std_logic_vector(WIDTH - 1 downto 0);
   signal wea : std_logic := '0';

   constant DATA : std_logic_vector(WIDTH - 1 downto 0) := "10101111";
   constant ADDR : unsigned(ADDR_WIDTH - 1 downto 0) := to_unsigned(17, ADDR_WIDTH);
   constant DATAX : std_logic_vector(WIDTH - 1 downto 0) := (others => 'X');

begin

   clka <= not clka after CLKA_PERIOD / 2;
   clkb <= not clkb after CLKB_PERIOD / 2;


   DUT : entity sim.Simple_Dual_Port_RAM
   generic map (
      WIDTH     => WIDTH,
      DEPTH     => DEPTH,
      DEAD_TIME => DEAD_TIME,
      PREFIX    => "DUT RAM: "
   ) port map (
      clka_i  => clka,
      addra_i => addra,
      dataa_i => dataa,
      wea_i   => wea,

      clkb_i  => clkb,
      addrb_i => addrb,
      datab_o => datab
   );


   main : process is
   begin
      wait for 2 * CLKA_PERIOD;

      addra <= ADDR;
      dataa <= DATA;
      addrb <= ADDR;
      wea <= '1';
      wait for CLKA_PERIOD;
      addra <= (others => '0');
      dataa <= (others => '0');
      wea <= '0';
      wait for DEAD_TIME;
      assert datab = DATAX
         report "datab = " & to_string(datab) & ", expecting " & to_string(DATAX)
         severity failure;
      wait for CLKB_PERIOD;
      assert datab = DATA
         report "datab = " & to_string(datab) & ", expecting " & to_string(DATA)
         severity failure;

      wait for 2 * CLKA_PERIOD;
      std.env.finish;
   end process;
end architecture;
