package memory

/* Simple infrastructure for a type to pass to CPU implementations.
   Each separate system will write their own Bus implementation that 
   write their own read/write functions that cast to the appropriate
   structure that uses this structure.

   Might need to write multiple structures that take different read/write types
   for 16 bit systems.
*/

ReadFn :: #type proc(bus: ^Bus, addr: u16) -> u8
WriteFn :: #type proc(bus: ^Bus, addr: u16, data: u8)

Bus :: struct {
	read:  ReadFn,
	write: WriteFn,
}
