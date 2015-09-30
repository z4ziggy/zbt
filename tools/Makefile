TARGETS = atshell attest bdaddr hcidump-crash hstest l2cap-packet l2cap_headersize_overflow rfcomm_shell bt_dos

CC = gcc
CFLAGS = -lbluetooth -lreadline -lncurses

all: $(TARGETS) carwhisperer bluesnarfer btobex btftp

$(TARGETS): %: %.c
	$(CC) $(CFLAGS) $< -o $@

carwhisperer::
	$(MAKE) -C carwhisperer-0.2
	cp carwhisperer-0.2/carwhisperer .

bluesnarfer::
	$(MAKE) -C bluesnarfer-git
	cp bluesnarfer-git/bluesnarfer .

btobex::
	$(MAKE) -C btobex-0.1
	cp btobex-0.1/btobex .

btftp::
	$(MAKE) -C btftp-git
	cp btftp-git/btftp .

clean:
	rm -f $(TARGETS) carwhisperer bluesnarfer btobex btobex-0.1/btobex btftp btftp-git/btftp
	$(MAKE) -C carwhisperer-0.2 clean
	$(MAKE) -C bluesnarfer-git clean
	#$(MAKE) -C btobex-0.1 clean
	#$(MAKE) -C btftp-git clean

