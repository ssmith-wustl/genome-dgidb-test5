package Genome::Sys::User;

use strict;
use warnings;
use Genome;

class Genome::Sys::User {
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    table_name => 'genome_sys_user',
    id_by => [
        email => { is => 'VARCHAR2', len => 255, column_name => 'EMAIL' },
    ],
    has_optional => [
        name => { is => 'VARCHAR2', len => 64, column_name => 'NAME' },
        username => {
            calculate_from => ['email'],
            calculate => sub { 
                my ($e) = @_;
                my ($u) = $e =~ /(.+)\@/; 
                return $u;
            }
        }
    ]
};



sub get {

    my ($self, @p) = @_;

    my %p = @p;
    if (scalar(@p) == 1) {
        # Genome::Sys::User->get('yermom');
        my $key = $p[0];
        delete $p{$key};
        $p{'email'} = $key;
    }

    if (defined($p{'email'}) 
        && $p{'email'} !~ /\@/) {
        my $old = $p{'email'};
        my $new = join('@',$p{'email'},Genome::Config::domain());
        warn "Trying to get() for '$old' - assuming you meant '$new'";
        $p{'email'} = $new;
    }

    return $self->SUPER::get(%p);
}

1;

