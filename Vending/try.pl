use above 'Vending';
#print "\n\n*** Get Cookie type!\n";
#my $c = Vending::Product->get(name => 'Cookie');

print "\n\n*** Get Cookies items\n";
my @c = Vending::VendItem->get(slot_name => { operator => 'like', value => 'chan%' });

1;
