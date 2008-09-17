package Genome::Model::Tools::PhredPhrap::Base;

use strict;
use warnings;

use above 'Genome';

#- PROPERTIES -#
my %properties = (
    project_name => {
        is_optional => 0,
        type => 'String',
        doc =>'Name of project',
    },
    directory => {
        type => 'String', 
        is_optional => 0,
        doc =>'Base directory to work in, with (or will create) chromat_dir, phd_dir and edit_dir.',
    },
    user  => {
        type => 'String',
        is_optional => 1,
        default => $ENV{USER},
        doc =>'User',
    }, 
    sub_assembly  => {
        type => 'String',
        is_optional => 1,
        doc =>'Name of asssembly, defalut will be project name',
    },
);

#- PROCESSOR CLASSES - ADD PROPS TO THIS CLASS -#
for my $processor ( pre_assembly_processors(), post_assembly_processors() ) {
    my $class = class_for_pre_assembly_processor($processor);
    use_class($class);

    $properties{"no_$processor"} = {
        type => 'Boolean',
        is_optional => 1,
        doc => "Do not run $processor",
    };

    my $acc_class_meta = $class->get_class_object;
    for my $property ( $acc_class_meta->get_property_objects ) {
        next if $property->property_name eq 'fasta_file'
            or exists $properties{ $property->property_name };
        $properties{ $property->property_name } = {
            type => $property->property_name,
            is_optional => 1,
            doc => "(for $processor) " . $property->doc,
        };
    }
}

class Genome::Model::Tools::PhredPhrap::Base {
    is => 'Genome::Model::Tools::PhredPhrap',
    is_abstract => 1,
    has => [ %properties ],
};

sub project {
    return $_[0]->{_project};
}

sub cwd {
    return $_[0]->{_cwd};
}

require Cwd;
use Data::Dumper;
use Finfo::ClassUtils 'use_class';
#require Finishing::Assembly::Factory;
require IO::File;

sub create { 
    my $class = shift;

    my $self = $class->SUPER::create;

    $self->_cwd( Cwd::getcwd() );
    $self->_create_busy_file;

    # Get project/directory
    my $project;
    unless ( defined $self->directory ) {
        my $gsc_factory = Finishing::Assembly::Factory->connect('gsc');
        $project = $gsc_factory->get_project(name => $self->project_name)
            or $self->fatal_msg("No base directory given and could not get GSC::Project for " . $self->project_name);
        $gsc_factory->disconnect;
    }

    unless ( $project ) {
        $self->fatal_msg(
            sprintf('Need directory to work in for project (%s)', $self->project_name) 
        ) unless -d $self->directory;

        $self->directory( Cwd::abs_path($self->directory) );
        
        my $src_factory = Finishing::Assembly::Factory->connect('source');
        $project = $src_factory->get_project(
            name => $self->project_name,
            directory => $self->directory,
        );
        $src_factory->disconnect;
    }

    $self->{_project} = $project;
    $project->create_consed_directory_structure;
    $self->assembly_name( $project->name ) unless $self->assembly_name;
    
    for my $file_method ( $self->_files_to_remove ) {
       my $file_name = $self->$file_method;
       unlink $file_name if -e $file_name;
    }
    
    return 1;
}

sub _files_to_remove {
    return (qw/ acefile singlets_file /);
}

sub DESTROY {
    my $self = shift;
    
    unlink $self->busy_file if -e $self->busy_file;
    
    chdir $self->_cwd;

    return 1;
}

my @options_with_defaults = (qw/
    assebmly_name scf_file exclude_file phd_file fasta_file qual_file
    /);
sub _AUTOLOAD {
    my ($self, $id, $arg) = @_;

    my $requested_method = $_;
    if ( grep { $requested_method eq $_ } @options_with_defaults ) {
        my $default_method = 'default_' . $requested_method;
        return sub{ return $self->$default_method };
    }

    return; 
}

#- BUSY FILE -#
sub busy_file {
    my $self = shift;
    
    return sprintf('%s/MKCS.BUSY', $self->directory);
}

sub _create_busy_file {
    my $self = shift;

    #$self->fatal_msg("MKCS process already running") if -e $self->busy_file;

    return IO::File->new('>' . $self->busy_file);
}

#- EXECUTE -#
sub execute {
    my $self = shift;

    $self->_handle_input;

    $self->info_msg("Pre Assembly Processing");
    for my $processor_name ( $self->pre_assembly_processors ) {
        my $no_processor = 'no_' . $processor_name ;
        next if $self->$no_processor;
        my $class = class_for_pre_assembly_processor($processor_name);
        my %params = $self->_params_for_class($class);
        my $processor = $class->new(%params);
        $processor->info_msg('Running');
        unless ( $processor->execute ) {
            $self->error_msg("Pre Assembly Processing failed, cannot assemble");
            return;
        }
    }

    my %params = $self->_params_for_class('Assembly::Commands::Phrap');
    my $phrap = Assembly::Commands::Phrap->new(%params);
    $phrap->info_msg("Assembling");
    $phrap->execute;

    #POST ASEMBLY PROCESS

    return 1;
}

sub _params_for_class {
    my ($self, $class) = @_;

    my %params_for_class;
    for my $attribute ( $class->attributes ) {
        my $value = $self->$attribute;
        next unless defined $value;
        $params_for_class{$attribute} = $value;
    }

    return %params_for_class;
}

#- INPUT PROCESSORS -#
sub assembly_processors_and_classes {
    return pre_assembly_processors_and_classes(), post_assembly_processors_and_classes();
}

sub pre_assembly_processors_and_classes { 
    return (
        #A_screen_vector => 'Genome::Model::Tools::Fasta::ScreenVector',
        B_trim_quality => 'Genome::Model::Tools::Fasta::TrimQuality',
    );
}

sub pre_assembly_processors {
    my %itnc = pre_assembly_processors_and_classes();
    return grep { s/^\w\_// } sort keys %itnc;
}

sub pre_assembly_processor_classes {
    my %itnc = pre_assembly_processors_and_classes();
    return values %itnc;
}

sub class_for_pre_assembly_processor {
    my ($processor) = @_;
    my %itnc = pre_assembly_processors_and_classes();
    my ($found) = grep { $_ =~ /$processor/ } keys %itnc;
    return $itnc{ $found };
}

#- POST ASSEMBLY PROCESSORS -#
sub post_assembly_processors_and_classes { 
    return (
        #'add-singlets' => 'Finishing::Assembly::Consed::Assembler::ScreenVector',
    );
}

sub post_assembly_processors {
    my %itnc = post_assembly_processors_and_classes();
    return sort keys %itnc;
}

sub post_assembly_processor_classes {
    my %itnc = post_assembly_processors_and_classes();
    return values %itnc;
}

sub class_for_post_assembly_processor {
    my ($processor) = @_;
    my %itnc = post_assembly_processors_and_classes();
    return $itnc{ $processor };
}

#- DIRS, FILES, DEFAULTS, ETC -#
sub edit_dir {
    my $self = shift;

    return $self->_project->edit_dir;
}

sub phd_dir {
    my $self = shift;

    return $self->_project->phd_dir;
}

sub chromat_dir {
    my $self = shift;

    return $self->_project->chromat_dir;
}

sub default_scf_file {
    my $self = shift;

    return sprintf('%s/%s.include', $self->_project->edit_dir, $self->assembly_name);
}

sub default_exclude_file {
    my $self = shift;

    return sprintf('%s/%s.exclude', $self->_project->edit_dir, $self->assembly_name);
}

sub default_phd_file {
    my $self = shift;

    return sprintf('%s/%s.phds', $self->_project->edit_dir, $self->assembly_name);
}

sub default_fasta_file {
    my $self = shift;

    return sprintf('%s/%s.fasta', $self->_project->edit_dir, $self->assembly_name);
}

sub default_qual_file {
    my $self = shift;

    return sprintf('%s.qual', $self->default_fasta_file);
}

sub acefile {
    my $self = shift;

    return sprintf('%s.ace', $self->default_fasta_file);
}

sub singlets_file {
    my $self = shift;

    return sprintf('%s.singlets', $self->default_fasta_file);
}

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
