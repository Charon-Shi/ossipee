import os

from keystoneclient.v3 import client as keystoneclient
from neutronclient.neutron import client as neutronclient
from novaclient import client as novaclient


from keystoneclient import session as ksc_session
from keystoneclient.auth.identity import v3
from keystoneclient.v3 import client as keystone_v3


router_name = 'rdo-router'
network_name='rdo-net'
subnet_name='rdo-subnet'


class WorkItem(object):
    def __init__(self, neutron):
        self.neutron = neutron

class Network(WorkItem):                
    def cleanup(self):
        for network in self.neutron.list_networks(name=network_name)['networks']:
            self.neutron.delete_network(network['id'])
        

    def create(self):    
        #openstack network create ayoung-private
        network = {'name': network_name, 'admin_state_up': True}
        self.neutron.create_network({'network':network})

    def display(self):
        print('network')

class SubNet(WorkItem):                
    def cleanup(self):
        for subnet in self.neutron.list_subnets(name=subnet_name)['subnets']:
            self.neutron.delete_subnet(subnet['id'])

    def create(self):    
        #neutron  subnet-create ayoung-private 192.168.52.0/24 --name ayoung-subnet1
        for network in self.neutron.list_networks(name=network_name)['networks']:
            print (network['name'])

        body_create_subnet = {
            "subnets": [
                {
                    "name": subnet_name,
                    "cidr": "192.168.52.0/24",
                    "ip_version": 4,
                    "network_id": network['id']
                }
            ]
        }
        
        subnet = self.neutron.create_subnet(body=body_create_subnet)

    def display(self):
        print('subnet')

        
class Router(WorkItem):                    
    def cleanup(self):
        for router in self.neutron.list_routers(name=router_name)['routers']:
            self.neutron.delete_router(router['id'])

    def create(self):    
            body_value = {'router': {
                'name' : router_name,
                'admin_state_up': True,
            }}
            router = self.neutron.create_router(body=body_value)

    def display(self):
        print('router')
        
        
#neutron router-create ayoung-private-router
#external_id=`neutron net-show external | awk '/ id / {print $4}'`
#neutron router-interface-add $external_id
        

        
        
#logging.basicConfig(level=logging.DEBUG)

class Worklist(object):
    def __init__(self):
        
        OS_AUTH_URL = os.environ.get('OS_AUTH_URL') 
        OS_USERNAME = os.environ.get('OS_USERNAME') 
        OS_PASSWORD= os.environ.get('OS_PASSWORD')
        OS_USER_DOMAIN_NAME=os.environ.get('OS_USER_DOMAIN_NAME')
        OS_PROJECT_DOMAIN_NAME=os.environ.get('OS_PROJECT_DOMAIN_NAME')
        OS_PROJECT_NAME=os.environ.get('OS_PROJECT_NAME')

        auth = v3.Password(auth_url=OS_AUTH_URL,
                           username=OS_USERNAME,
                           user_domain_name=OS_USER_DOMAIN_NAME,
                           password=OS_PASSWORD,
                           project_name=OS_PROJECT_NAME,
                           project_domain_name=OS_PROJECT_DOMAIN_NAME)


        session = ksc_session.Session(auth=auth)
        keystone = keystone_v3.Client(session=session)
        nova = novaclient.Client('2', session=session)
        neutron = neutronclient.Client('2.0', session=session)
        neutron.format = 'json'


        work_item_classes =[Network,SubNet,Router]

        self.work_items = []

        for item_class in work_item_classes:
            self.work_items.append(item_class(neutron))


    def setup(self):
        for item in self.work_items:
            item.create()
        
    def teardown(self):
        for item in reversed(self.work_items):
            item.cleanup()

    def display(self):
        for item in self.work_items:
            item.display()
    

def setup():
    Worklist().setup()
    
def teardown():
    Worklist().teardown()

def display():
    wl = Worklist()
    wl.display()