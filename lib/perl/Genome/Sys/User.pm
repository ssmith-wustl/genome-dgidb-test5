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
        project_parts => { is => 'Genome::ProjectPart', reverse_as => 'entity', },
        projects => { is => 'Genome::Project', via => 'project_parts', to => 'project', },
        project_names => { is => 'Text', via => 'projects', to => 'name', },
        username => {
            calculate_from => ['email'],
            calculate => sub { 
                my ($e) = @_;
                my ($u) = $e =~ /(.+)\@/; 
                return $u;
            }
        }
    ],
    has_many_optional => [
        project_parts => { is => 'Genome::ProjectPart', reverse_as => 'entity', is_mutable => 1, },
        projects => { is => 'Genome::Project', via => 'project_parts', to => 'project', is_mutable => 1, },
        project_names => { is => 'Text', via => 'projects', to => 'name', },
    ],
};

sub fix_params_and_get {
    my ($class, @p) = @_;
    my %p;
    if (scalar(@p) == 1) {
        my $key = $p[0];
        $p{'email'} = $key;
    }
    else {
        %p = @p;
    }

    if (defined($p{'email'}) 
        && $p{'email'} !~ /\@/) {
        my $old = $p{'email'};
        my $new = join('@',$p{'email'},Genome::Config::domain());
        warn "Trying to get() for '$old' - assuming you meant '$new'";
        $p{'email'} = $new;
    }

    return $class->SUPER::get(%p);
}

1;

