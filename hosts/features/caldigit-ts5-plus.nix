{ ... }:

{
  # Intentionally empty.
  #
  # The previous dock-specific recovery logic made the TS5 Plus worse on this
  # machine by touching the dock's tunneled PCIe xHCI controller while it was
  # already failing to initialize. Leave the dock to the kernel/firmware default
  # path until the BIOS/dock firmware situation is sorted out.
}
