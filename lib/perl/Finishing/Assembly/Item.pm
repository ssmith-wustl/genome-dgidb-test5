package Genome::Site::WUGC::Finishing::Assembly::Item;

use Finfo::Std;

use Data::Dumper;

my %proxy :name(proxy:r);

sub AUTOMETHOD
{
    my ($self, $id, @args) = @_;

    return $self->proxy->get_method($_, @args);
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/branches/adukes/AssemblyRefactor/Item.pm $
#$Id: Item.pm 31442 2008-01-03 23:47:59Z adukes $
