
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
        },
        output => {
            is_optional => 1,
            is => 'String',
            doc => 'XML string'
        },
        'print' => {
            is => 'Boolean',
            doc => 'Prints XML to stdout by default',
            default_value => 1
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
    
    my $inputs = '';
    my $outputs = '';
    my $command = $class_name->command_name;
    # get command class 'has' attributes
    my $cls_has = $class_meta->{has};
    # get has' attrs
    my @has_attrs = keys %{$cls_has};
    # iterate through and check for input/output files
    # we build the galaxy <inputs> and <outputs> sections as we go
    foreach my $attr (@has_attrs) 
    {
        my $sub_hsh = $cls_has->{$attr};
        my $file_type = $sub_hsh->{file_type};
        if (($sub_hsh->{is_input} || $sub_hsh->{is_output}) and !defined($file_type)) {
            # lets warn them about not defining a file_type on an input or output file
            $self->warning_message("Input or output file_type is not defined on attribute $attr. Falling back to 'text'");
            $file_type = 'text';
        }
        if ($sub_hsh->{is_input})
        {
            $inputs .= '<param name="'.$attr.'" format="'.$file_type.'" type="data" help="" />' . "\n";
        } 
        elsif ($sub_hsh->{is_output})
        {
            $outputs .= '<data name="'.$attr.'" format="'.$file_type.'" label="" help="" />' . "\n";
        }
        $command .= " --$attr=\$$attr";
    }

    my $help_brief  = $class_name->help_brief;
    my $help_detail;
    {
        local $ENV{ANSI_COLORS_DISABLED} = 1;
        $help_detail = $class_name->help_usage_complete_text;
    }

    my $tool_id = $class_name->command_name;
    $tool_id =~ s/ /_/g;

    # galaxy will bold headers surrounded by * like **THIS**
    $help_detail =~ s/^([A-Z]+[A-Z ]+:?)/**$1**\n/mg;

    my $xml = <<"    XML";
<tool id="$tool_id" name="$tool_id">
  <description>
    $help_brief
  </description>
  <command>
    $command
  </command>
  <inputs>
    $inputs
  </inputs>
  <outputs>
    $outputs
  </outputs>
  <help>
    $help_detail
  </help>
</tool>
    XML

    print $xml if $self->print;

    $self->output($xml);
    return 1
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

