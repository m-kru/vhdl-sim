library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

library sim;


entity tb_simple_dual_port_ram_common_clock is
   generic (
      READ_LATENCY : positive
   );
end entity;

architecture test of tb_simple_dual_port_ram_common_clock is

   constant WIDTH : positive := 8;
   constant DEPTH : positive := 8192;
   constant ADDR_WIDTH : positive := 13;

   constant CLK_PERIOD : time := 10 ns;
   signal clk : std_logic := '0';

   signal addra, addrb : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
   signal dataa, datab : std_logic_vector(WIDTH - 1 downto 0);
   signal wea : std_logic := '0';

   constant DATA : std_logic_vector(7 downto 0) := "10101111";
   constant ADDR : unsigned(ADDR_WIDTH - 1 downto 0) := to_unsigned(5113, ADDR_WIDTH);

   constant SEQUENTIAL_TEST_LENGTH : positive := 123;

begin

   clk <= not clk after CLK_PERIOD / 2;


   DUT : entity sim.Simple_Dual_Port_RAM
   generic map (
      WIDTH => WIDTH,
      DEPTH => DEPTH,
      COMMON_CLOCK => true,
      READ_LATENCY => READ_LATENCY
   ) port map (
      clka_i  => clk,
      addra_i => addra,
      dataa_i => dataa,
      wea_i   => wea,

      clkb_i  => clk,
      addrb_i => addrb,
      datab_o => datab
   );


   main : process is

      procedure single_write_read_test is
      begin
         report "Testing single write and read, addr = " & to_string(ADDR) & ", data = " & to_string(DATA);
         addra <= ADDR;
         dataa <= DATA;
         wea <= '1';
         wait for CLK_PERIOD;
         addra <= (others => '0');
         dataa <= (others => '0');
         wea <= '0';
         addrb <= ADDR;
         wait for READ_LATENCY * CLK_PERIOD;
         assert datab = DATA
            report "datab = " & to_string(datab) & ", expecting " & to_string(DATA)
            severity failure;
         addrb <= (others => '0');
      end procedure;

      procedure sequential_write_read_test is
         variable expected : std_logic_vector(WIDTH - 1 downto 0);
      begin
         report " Testing sequential write and read";
         addra <= (others => '0');
         dataa <= (others => '0');
         wea   <= '0';
         addrb <= (others => '0');
         wait for CLK_PERIOD;
         wea <= '1';
         for i in 0 to SEQUENTIAL_TEST_LENGTH - 1 loop
            addra <= to_unsigned(i, ADDR_WIDTH);
            dataa <= std_logic_vector(to_unsigned(i, WIDTH));

            if i > READ_LATENCY then
               expected := std_logic_vector(to_unsigned(i-READ_LATENCY-1, WIDTH));
               assert datab = expected
                  report "datab = " & to_string(datab) & ", expecting " & to_string(expected)
                  severity failure;
            end if;
            if i > 1 then
               addrb <= addrb + 1;
            end if;
            wait for CLK_PERIOD;
         end loop;
         wea <= '0';
      end procedure;

   begin
      wait for 3 * CLK_PERIOD;

      single_write_read_test;
      sequential_write_read_test;

      wait for 3 * CLK_PERIOD;
      std.env.finish;
   end process;
end architecture;
