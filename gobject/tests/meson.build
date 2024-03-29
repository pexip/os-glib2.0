subdir('performance')

marshalers_h = custom_target('marshalers_h',
  output : 'marshalers.h',
  input : 'marshalers.list',
  command : [
    python, glib_genmarshal,
    '--prefix=test',
    '--valist-marshallers',
    '--output=@OUTPUT@',
    '--quiet',
    '--header',
    '@INPUT@',
  ],
)
marshalers_c = custom_target('marshalers_c',
  output : 'marshalers.c',
  input : 'marshalers.list',
  command : [
    python, glib_genmarshal,
    '--prefix=test',
    '--valist-marshallers',
    '--include-header=marshalers.h',
    '--output=@OUTPUT@',
    '--quiet',
    '--body',
    '@INPUT@',
  ],
)

gobject_tests = {
  'notify-init' : {},
  'notify-init2' : {},
  'custom-dispatch' : {},
  'qdata' : {},
  'accumulator' : {
    'source' : ['accumulator.c', marshalers_h, marshalers_c],
  },
  'basics-gobject' : {},
  'boxed' : {},
  'defaultiface' : {
    'source' : ['defaultiface.c', 'testmodule.c'],
  },
  'deftype' : {},
  'deprecated-properties' : {},
  'dynamictype' : {
    'source' : ['dynamictype.c', 'testmodule.c'],
  },
  'enums' : {},
  'override' : {},
  'param' : {},
  'references' : {},
  'basic-signals' : {},
  'singleton' : {},
  'threadtests' : {},
  'dynamictests' : {},
  'binding' : {},
  'bindinggroup' : {},
  'properties' : {},
  'reference' : {},
  'flags' : {},
  'value' : {},
  'type' : {},
  'gobject-private' : {
    'source' : 'private.c',
  },
  'closure' : {},
  'closure-refcount' : { 'suite': ['slow'] },
  'object' : {},
  'signal-handler' : {},
  'ifaceproperties' : {},
  'signals' : {
    'source' : ['signals.c', marshalers_h, marshalers_c],
  },
  'signalgroup' : {},
  'testing' : {},
  'type-flags' : {},
  'objects-refcount1' : {},
  'objects-refcount2' : {'suite' : ['slow']},
  'properties-refcount1' : {},
  'properties-refcount2' : {'suite' : ['slow']},
  'properties-refcount3' : {'suite' : ['slow']},
  'properties-refcount4' : {},
  'signals-refcount1' : {
    'source' : 'signals-refcount.c',
    'c_args' : ['-DTESTNUM=1'],
  },
  'signals-refcount2' : {
    'source' : 'signals-refcount.c',
    'c_args' : ['-DTESTNUM=2'],
  },
  'signals-refcount3' : {
    'source' : 'signals-refcount.c',
    'c_args' : ['-DTESTNUM=3'],
  },
  'signals-refcount4' : {
    'source' : 'signals-refcount.c',
    'c_args' : ['-DTESTNUM=4'],
  },
}

if have_cxx
  gobject_tests += {
    'cxx' : {
      'source' : ['cxx.cpp'],
      'suite' : ['cpp'],
    },
  }

  foreach std, arg: cxx_standards
    gobject_tests += {
      'cxx-@0@'.format(std) : {
        'source' : ['cxx.cpp'],
        'suite' : ['cpp'],
        'cpp_args' : [arg],
      },
    }
  endforeach
endif

if cc.get_id() != 'msvc'
  gobject_tests += {'autoptr' : {}}
endif

python_tests = [
  'genmarshal.py',
  'gobject-query.py',
  'mkenums.py',
]

# FIXME: put common bits of test environment() in one location
test_env = environment()
test_env.set('G_TEST_SRCDIR', meson.current_source_dir())
test_env.set('G_TEST_BUILDDIR', meson.current_build_dir())
test_env.set('G_DEBUG', 'gc-friendly')
test_env.set('MALLOC_CHECK_', '2')

test_deps = [libm, thread_dep, libglib_dep, libgobject_dep]
test_cargs = ['-DG_LOG_DOMAIN="GLib-GObject"', '-UG_DISABLE_ASSERT']
test_cpp_args = test_cargs

foreach test_name, extra_args : gobject_tests
  source = extra_args.get('source', test_name + '.c')
  install = installed_tests_enabled and extra_args.get('install', true)

  if install
    test_conf = configuration_data()
    test_conf.set('installed_tests_dir', installed_tests_execdir)
    test_conf.set('program', test_name)
    test_conf.set('env', '')
    configure_file(
      input: installed_tests_template_tap,
      output: test_name + '.test',
      install_dir: installed_tests_metadir,
      install_tag: 'tests',
      configuration: test_conf
    )
  endif

  exe = executable(test_name, source,
    c_args : test_cargs + extra_args.get('c_args', []),
    cpp_args : test_cpp_args + extra_args.get('cpp_args', []),
    dependencies : test_deps + extra_args.get('dependencies', []),
    install_dir: installed_tests_execdir,
    install_tag: 'tests',
    install: install,
  )

  suite = ['gobject'] + extra_args.get('suite', [])
  timeout = suite.contains('slow') ? test_timeout_slow : test_timeout

  # FIXME: https://gitlab.gnome.org/GNOME/glib/issues/1316
  # aka https://bugs.debian.org/880883
  if test_name == 'closure-refcount' and ['arm', 'aarch64'].contains(host_machine.cpu_family())
    timeout = timeout * 10
  endif

  test(test_name, exe, env : test_env, timeout : timeout, suite : suite)
endforeach

foreach test_name : python_tests
  test(
    test_name,
    python,
    args: ['-B', files(test_name)],
    env: test_env,
    suite: ['gobject', 'no-valgrind'],
  )

  if installed_tests_enabled
    install_data(
      files(test_name),
      install_dir: installed_tests_execdir,
      install_tag: 'tests',
      install_mode: 'rwxr-xr-x',
    )

    test_conf = configuration_data()
    test_conf.set('installed_tests_dir', installed_tests_execdir)
    test_conf.set('program', test_name)
    test_conf.set('env', '')
    configure_file(
      input: installed_tests_template_tap,
      output: test_name + '.test',
      install_dir: installed_tests_metadir,
      install_tag: 'tests',
      configuration: test_conf,
    )
  endif
endforeach

# TAP test runner for Python tests
if installed_tests_enabled
  install_data(
    files('taptestrunner.py'),
    install_dir: installed_tests_execdir,
    install_tag: 'tests',
  )
endif
