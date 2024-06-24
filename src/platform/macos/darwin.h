#include <mach/kern_return.h>
#include <mach/mach.h>

kern_return_t mach_vm_read_overwrite
(
	vm_map_read_t target_task,
	mach_vm_address_t address,
	mach_vm_size_t size,
	mach_vm_address_t data,
	mach_vm_size_t *outsize
);

kern_return_t mach_vm_region
(
	vm_map_read_t target_task,
	mach_vm_address_t *address,
	mach_vm_size_t *size,
	vm_region_flavor_t flavor,
	vm_region_info_t info,
	mach_msg_type_number_t *infoCnt,
	mach_port_t *object_name
);

kern_return_t mach_vm_deallocate
(
	vm_map_t target,
	mach_vm_address_t address,
	mach_vm_size_t size
);
