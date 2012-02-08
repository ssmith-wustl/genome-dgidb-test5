package Genome::Subject::Command::Import;

use strict;
use warnings;

use Genome;
use MIME::Types;
use MIME::Base64;
use Text::CSV;
use IO::Scalar;

class Genome::Subject::Command::Import {
    is => 'Command',
    has => [
       nomenclature_id => { is => 'Text' },
       nomenclature    => { is => 'Genome::Nomenclature', id_by=>'nomenclature_id' },
       nomenclature_name    => { is => 'Text', via=>'nomenclature', to=>'name' },
       subclass_name   => { is => 'Text' },
       project_name    => { is => 'Text' },
       decoded_content => { calculate_from => ['content'], calculate => q|MIME::Base64::decode_base64($content)|}
    ],
    has_optional => [
       content  => { is => 'Text' },
       filename => { is => 'Text' }
    ],
};

sub help_brief {
    return 'Import subjects/attributes from web';
}

sub create {

    my ($class, %p) = @_;

    if (my $f = $p{'filename'}) {

        if ($p{'content'}) {
            warn "You passed a filename and some content- ignoring the filename, using content";
        } else {
            $p{'content'} = do {
                local $/ = undef;
                open(my $fh, $f);
                my $c = <$fh>;
                close($fh); 
                $c;
            };
        }
    } elsif (! $p{'content'}) {
        die "Error: you must pass either --filename or --content as an argument";
    }
 
    return $class->SUPER::create(%p);
}

sub execute {

    my ($self) = @_;

    # one project per upload
    my $project = Genome::Project->create(name => $self->project_name);


    # Assumes first row contains column names
    # Assumes first col is the name of the object or
    #   blank to create a new object

    my $subclass_name = $self->subclass_name();

    # data can come in from a filename or directly (and encoded)
    my $raw = $self->filename ? $self->content() : $self->decoded_content();

    my $fh = new IO::Scalar \$raw;
    my $csv = Text::CSV->new();
    my @header;
    my $field = {};

    my $i = 0;
    my $added;
    ROW:
    while (my $row = $csv->getline($fh)) {
        
        if ( $i++ == 0 ) { 
            @header = @$row; 
            $field = $self->check_types(@header);
            next ROW; 
        }

        my @values = @$row;  

        if (@header != @values) {
            warn "Skipping row - number of columns, values, and types dont match: $subclass_name with name "
                . $row->[0];
            next ROW;
        }


        my $obj = $subclass_name->get(name => $row->[0]);

        
        if ( !$obj ) {
            warn "Skipping row- couldnt get object: $subclass_name with name: "
                . $header[0];
            next ROW;
        }


        my $j = -1;
        VALUE:
        for my $v (@values) {

            if (++$j == 0) { next VALUE; } # first value should be the obj's "name"

            my $col_name = $header[$j];
            my $f = $field->{$col_name};
            if ($f->type() eq 'enumerated') {
                my @acceptable_values = map {$_->value} $f->enumerated_values();
                if (! grep /^$v$/, @acceptable_values) {
                    my $nom = $self->nomenclature();
                    warn "Skipping value '$v' because its not a valid option for $col_name with nomenclature: "
                            . $nom->name;
                    next VALUE;
                }
            }

            my $sa = Genome::SubjectAttribute->get(
                subject_id      => $obj->id,
                attribute_label => $col_name,
                nomenclature    => $f->id
            );

            if ($sa) { 
                $sa->delete;
            }
            $sa = Genome::SubjectAttribute->create(
                subject_id      => $obj->id,
                attribute_label => $col_name,
                attribute_value => $v,
                nomenclature    => $f->id
            );
            $added++; 
        }

        # add each subject obj to the project
        $project->add_part( entity => $obj, role => 'automatic');
    }

    return $added;
}

sub check_types {

    my ($self, @header) = @_;

    my $nom = $self->nomenclature();
    my @fields = $nom->fields();
    my %field = map {$_->name => $_} @fields;

    my $i = 0;
    COLUMN_NAME:
    for my $h (@header) {

        if ($i++ == 0) { next COLUMN_NAME; } # first is the subject name
        if (!defined($field{$h})) {
            die "Error: column '$h' is not a field in nomenclature '"
                . $nom->name . "'";
        }
    }

    return \%field;
}




1;


