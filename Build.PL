use Module::Build;

my $class = Module::Build->subclass(
	 class => 'CGI::Session::PureSQL::Builder',
	   code => q{
	 	sub ACTION_dist {
			my $self = shift;
			use Pod::Text;
			my $parser = Pod::Text->new;
			$parser->parse_from_file('./lib/CGI/Session/PureSQL.pm', 'README');
			$self->SUPER::ACTION_dist;
	 	}
	},
);


$class->new(
     module_name     => 'CGI::Session::PureSQL',
      license         => 'perl',
	  requires => {
		  'CGI::Session'  => 3.95,
		  'SQL::Abstract' => 0,
		  'Date::Calc'	  => 0,
	  },
    )->create_build_script;
