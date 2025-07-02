// ==============================================================================================
// Name : niosII_uart_tx_rx.tcl
// Author : Guillaume Massé
// Description : C programme to test UART transmission and reception with Nios II
// ==============================================================================================
#include <stdio.h>
#include <sys/alt_stdio.h>
#include <sys/alt_alarm.h>
#include <sys/alt_timestamp.h>
#include <stdbool.h>
#include "altera_avalon_pio_regs.h"
#include "system.h"
#include <string.h>
#include "sys/alt_irq.h"

int pattern = 0; // Pattern used to control the 7-segment display LEDs

volatile char uart_rx_char = '0'; // Variable to store data received from UART

// Interrupt Service Routine (ISR) called when UART receives data
void uart_rx_handler(void* context) {
  uart_rx_char = IORD_ALTERA_AVALON_PIO_DATA(UART_0_BASE); // Read received character from UART
  alt_printf("Interrupt triggered\n");
  alt_printf("%c\n", uart_rx_char); // Print the received character
}

// Function to initialize UART interrupt
void init_uart_irq() {
  alt_irq_register(
    UART_0_IRQ,       // IRQ number of the UART
    NULL,             // No specific context needed
    uart_rx_handler   // ISR to handle UART receive
  );
}

int main()
{
  alt_putstr("Hello from Nios II!\n");

  init_uart_irq(); // Initialize UART interrupt

  IOWR_ALTERA_AVALON_PIO_DATA(LED_BASE, pattern); // Initialize LED pattern to 0

  // Initialize timestamp timer
  if (alt_timestamp_start() < 0) {
    alt_printf("Error: No timer available\n");
    return -1;
  }

  const alt_u64 freq = alt_timestamp_freq();   // Get timer frequency
  const alt_u64 delai_ms = 50;                 // Delay duration in milliseconds

  const alt_u64 ticks_par_ms = freq / 1000;    // Timer ticks per millisecond
  const alt_u64 delai_ticks = delai_ms * ticks_par_ms; // Total ticks for the desired delay

  int i = 0;

  alt_u64 init_time = alt_timestamp(); // Store initial timestamp
  alt_u64 t_prev = init_time;          // Store last tick timestamp
  int nb_sec = 0;                      // Counter for seconds elapsed

  char uart_char[50];                 // Buffer to format message to UART

  while (1) {
    // Reinitialize the timer each loop
    if (alt_timestamp_start() < 0) {
      alt_printf("Error: No timer available\n");
      return -1;
    }

    pattern = 1; // Starting pattern for LED shifting
    i = 0;

    // Loop to animate LED pattern (shift left then right)
    while (i < 19) {
      alt_u32 t_now = alt_timestamp();        // Current timestamp
      alt_u32 interval = t_now - t_prev;      // Elapsed time

      if (interval >= delai_ticks) {          // Wait until 50ms has passed
        IOWR_ALTERA_AVALON_PIO_DATA(LED_BASE, pattern); // Output current pattern to LEDs
        if (i < 9) {
          pattern = pattern << 1;             // Shift left during the first half
        } else {
          pattern = pattern >> 1;             // Shift right during the second half
        }
        i++;
        t_prev = alt_timestamp();             // Update previous timestamp
      }
    }

    nb_sec++; // Increment second counter

    // Extract individual digits from the second counter
    int digit_3 = (nb_sec / 1000) % 10;
    int digit_2 = (nb_sec / 100) % 10;
    int digit_1 = (nb_sec / 10) % 10;
    int digit_0 = nb_sec % 10;

    // Combine digits into a packed format for the 7-segment display
    int number = (digit_3 << 12) | (digit_2 << 8) | (digit_1 << 4) | digit_0;

    printf("Nb of sec: %d\n", nb_sec); // Print seconds count to console

    sprintf(uart_char, "Nb of sec: %d\n\r", nb_sec); // Format message for UART

    i = 0;
    // Send message over UART character by character
    while (uart_char[i] != '\0') {
      IOWR_ALTERA_AVALON_PIO_DATA(UART_0_BASE, uart_char[i]);
      i++;
    }

    // Send the packed number to the 7-segment display
    IOWR_ALTERA_AVALON_PIO_DATA(SEVENSEG_0_BASE, number);
  }

  return 0;
}
