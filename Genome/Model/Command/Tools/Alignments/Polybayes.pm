package Genome::Model::Command::Tools::Alignments::Polybayes;

use strict;
use warnings;

use above "Genome";
use Command;
use File::Path;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'dir'   => { type => 'String',  doc => "Polybayes alignment (output) directory"},
        'bindir'   => { type => 'String',  doc => "directory for binary executables for polybayes", is_optional => 1}
    ], 
);

sub help_brief {
    "add an alignment to Polybayes"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
add an alignment to Polybayes
EOS
}

#sub create {                               # Rarely implemented.  Initialize things before execute <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

#sub validate_params {                      # Pre-execute checking.  Not requiried <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

sub execute {
    my $self = shift;
		my($sample, $dir, $bindir) = 
				 ($self->sample, $self->dir, $self->bindir);
		$bindir ||= '/gscmnt/sata114/info/medseq/pkg/bin64';
		return unless ( defined($sample) && defined($dir)
									);
		my $ace2baa ||= "$bindir/ace2Baa";

		$dir =~ s/ \/ $ //x;					# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $dir) {
			mkpath $dir;
		}

		system("cd $dir ; $ace2baa --ace edit_dir/$sample.ace --baa $sample.baa");
}

1;


