
package Genome::Model::Tools::Galaxy::GenerateToolXml;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Galaxy::GenerateToolXml {
    is  => 'Command',
    has => [
        class_name => {
            is  => 'String',
            doc => 'Input class name'
        }
    ]
};

sub execute {
    my $self = shift;

    $DB::single=1;

    my $class_name = $self->class_name;
    {
        eval "use " . $self->class_name;
        if ($@) {
            die $@;
        }
    }

    my $class_meta = $class_name->get_class_object;
    if ( !$class_meta ) {
        $self->error_message("Invalid command class: $class_name");
        return 0;
    }

    my $help_brief  = $class_name->help_brief;
    my $help_detail = $class_name->help_detail;

    my $tool_id = 'dummyval'; #TODO
    my $tool_name = $class_name->command_name;
    my $command_line = $tool_name;
    my $input_params = '';
    my $output_data = '';
    
    my @property_meta = $class_meta->all_property_metas();

    my %categories = bin_properties(
        \@property_meta,
        required_input => sub {
            !$_[0]->is_optional
            && (defined $_[0]->{'is_input'}
                && $_[0]->{'is_input'})
            && !(defined $_[0]->{'is_output'}
                && $_[0]->{'is_output'});
        },
        optional_input => sub {
            $_[0]->is_optional
            && (defined $_[0]->{'is_input'}
                && $_[0]->{'is_input'})
            && !(defined $_[0]->{'is_output'}
                && $_[0]->{'is_output'});
        },
        required_both => sub {
            !$_[0]->is_optional
            && (defined $_[0]->{'is_input'}
                && $_[0]->{'is_input'})
            && (defined $_[0]->{'is_output'}
                && $_[0]->{'is_output'});
        },
        optional_both => sub {
            $_[0]->is_optional
            && (defined $_[0]->{'is_input'}
                && $_[0]->{'is_input'})
            && (defined $_[0]->{'is_output'}
                && $_[0]->{'is_output'});
        },
        output => sub {
            !(defined $_[0]->{'is_input'}
                && $_[0]->{'is_input'})
            && (defined $_[0]->{'is_output'}
                && $_[0]->{'is_output'});
        }
    );

    my @args = ();

    foreach my $p (@{ $categories{required_input} }) {
#        print Data::Dumper->new([$p])->Dump;

        my $line = '<param';

        $line .= ' name="' . $p->property_name . '"';

        if ($p->data_type eq 'file_path') {
            $line .= ' type="data"';
            $line .= ' format="' . $p->{'file_format'} . '"';
        } else {
            $line .= ' type="' . $p->data_type . '"';

            if ($p->data_length) {
                $line .= ' size="' . $p->data_length . '"';
            }
            if ($p->default_value) {
                $line .= ' value="' . $p->default_value . '"';
            }
        }        


        $line .= '/>';
        
        $input_params .= "\n    $line";

        push @args, $p->property_name;
    }
    
    foreach my $p (@{ $categories{required_both} }) {
        if ($p->data_type eq 'file_path') {
            my $line = '<data';
        
            $line .= ' name="' . $p->property_name . '"';
            if ($p->{'same_as'}) {
                $line .= ' format="input"';
                $line .= ' metadata_source="' . $p->{'same_as'} . '"';
            } else {
                $line .= ' format="' . $p->{'file_format'} . '"';
            }
        
            $line .= '/>';
        
            $output_data .= "\n    $line";

            push @args, $p->property_name;
        }
    }

    foreach my $pn (@args) {
        my $option = $pn;
        $option =~ s/_/-/g;

        $command_line .= ' --' . $option . '=$' . $pn;
    }

    my $xml = <<"    XML";
<tool id="$tool_id" name="$tool_name">
  <description>$help_brief</description>
  <command>$command_line</command>
  <inputs>$input_params
  </inputs>
  <outputs>$output_data
  </outputs>
  <help>
$help_detail
  </help>
</tool>
    XML

    print $xml;
}

sub bin_properties {
    my ($properties, %spec) = @_;
    
    my %output = map { $_ => [] } keys %spec;
    foreach my $p (@$properties) {
        my @matched = grep {
            $spec{$_}->($p)
        } keys %spec;
        
        for (@matched) {
            push @{ $output{$_} }, $p;
        }
    }

    return %output;
}

