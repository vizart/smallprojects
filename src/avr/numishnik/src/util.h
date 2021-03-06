/// \file
/// \brief Utilities
///
/// Bit settings. BCD conversions. Calendar.
///
#ifndef _UTIL_H
#define _UTIL_H

#define BV2(a,b) (_BV(a)|_BV(b))
#define BV3(a,b,c) (_BV(a)|_BV(b)|_BV(c))
#define BV4(a,b,c,d) (_BV(a)|_BV(b)|_BV(c)|_BV(d))
#define BV5(a,b,c,d,e) (_BV(a)|_BV(b)|_BV(c)|_BV(d)|_BV(e))
#define BV6(a,b,c,d,e,f) (_BV(a)|_BV(b)|_BV(c)|_BV(d)|_BV(e)|_BV(f))
#define BV7(a,b,c,d,e,f,g) (_BV(a)|_BV(b)|_BV(c)|_BV(d)|_BV(e)|_BV(f)|_BV(g))

/// Make BCD time from 2 bytes
#define maketime(hh,mm) (((hh) << 8) + (mm))

/// Convert to binary from BCD representation 
/// \see frombcd
#define _frombcd(x) ((x & 017) + (((x) & 0160)>>4) * 10)

/// Convert to binary from BCD representation as a function.
/// \see _frombcd
uint8_t frombcd(uint8_t);

uint16_t tobcd16(uint16_t);

/// Return BCD count of days in month for given BCD year and month.
/// Valid only for years 2000-2099.
uint8_t days_in_month_bcd(uint8_t year, uint8_t month);

/// Increment BCD value by 1
uint8_t bcd_increment(uint8_t x);

/// Get day of week, 0 = Sunday. Input parameters are binary (not BCD)
uint8_t day_of_week(uint8_t y, uint8_t m, uint8_t d);

/// Set blinkmode
void blinkmode_set(uint8_t mode);

/// Get blinkmode
uint8_t blinkmode_get();

/// Called every blink, unless NULL
void (*blinkhandler)(uint8_t);

/// Sets fading mode and speed
/// \see _fademode
void fade_set(uint8_t mode);

void fadeto(uint16_t t);

uint16_t get_display_value();

/// Cycle display modes
/// \see _displaymode
void mode_next();

/// get display mode
/// \see _displaymode
uint8_t mode_get();

void savingmode_set(uint8_t s);
uint8_t savingmode_get();
void savingmode_next();

// see dot blinking mode
// \see _dotmode
void dotmode_set(uint8_t mode);


#endif
