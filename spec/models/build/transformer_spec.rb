require 'spec_helper'

module Build
  describe Transformer do
    context '#compute_transformations' do
      def targets(asset_paths, main_paths = [])
        Paths.new(Transformer.compute_transformations(
          'foobar',
          Paths.new(asset_paths),
          Paths.new(main_paths)
        )[:all].values)
      end

      def mappings(asset_paths, main_paths = [])
        Hash[Transformer.compute_transformations(
          'foobar',
          Paths.new(asset_paths),
          Paths.new(main_paths)
        )[:all].invert.map { |s, t| [s.to_s, t.to_s] }]
      end

      it 'puts javascript files to javascripts directory' do
        expect(
          targets(['foo.js'])
        ).to eq(Paths.new(['vendor/assets/javascripts/foobar/foo.js']))
      end

      it 'puts stylesheet files to stylesheets directory' do
        expect(
          targets(['foo.css'])
        ).to eq(Paths.new(['vendor/assets/stylesheets/foobar/foo.scss']))
      end

      it 'puts image files to images directory' do
        expect(
          targets(['foo.png'])
        ).to eq(Paths.new(['vendor/assets/images/foobar/foo.png']))
      end

      it 'ignores minified files' do
        expect(
          targets(['foo.min.js', 'foo.js'])
        ).to eq(Paths.new(['vendor/assets/javascripts/foobar/foo.js']))
      end

      it 'ignores gzip, map and nuspec files' do
        expect(
          targets(['foo.min.js.gzip', 'foo.js.nuspec', 'foo.js.map', 'foo.nuspec.js'])
        ).to eq(Paths.new(['vendor/assets/javascripts/foobar/foo.nuspec.js']))
      end

      it 'leaves minified files that dont have unminified versions' do
        expect(
          targets(['foo.min.js'])
        ).to eq(Paths.new(['vendor/assets/javascripts/foobar/foo.min.js']))
      end

      it 'generates manifest for javascript files' do
        expect(
          targets(['foo.js'], ['foo.js'])
        ).to eq(Paths.new([
          'vendor/assets/javascripts/foobar/foo.js',
          'vendor/assets/javascripts/foobar.js'
        ]))
      end

      it 'generates proper javascript manifest' do
        expect(
          mappings(
            ['foo.js'], ['foo.js']
          )['vendor/assets/javascripts/foobar.js']
        ).to include('require foobar/foo.js')
      end

      it 'generates manifest for stylesheet files' do
        expect(
          targets(['foo.css'], ['foo.css'])
        ).to eq(Paths.new([
          'vendor/assets/stylesheets/foobar/foo.scss',
          'vendor/assets/stylesheets/foobar.scss'
        ]))
      end

      it 'generates proper stylesheet manifest' do
        expect(
          mappings(
            ['foo.css'], ['foo.css']
          )['vendor/assets/stylesheets/foobar.scss']
        ).to include("@import 'foobar/foo.scss';")
      end

      it 'flattens paths for if main javascript is set' do
        expect(
          targets(['dist/foo.js'], ['dist/foo.js'])
        ).to eq(Paths.new([
          'vendor/assets/javascripts/foobar/foo.js',
          'vendor/assets/javascripts/foobar.js'
        ]))
      end

      it 'flattens paths for if main stylesheet is set' do
        expect(
          targets(['dist/css/foo.css'], ['dist/css/foo.css'])
        ).to eq(Paths.new([
          'vendor/assets/stylesheets/foobar/foo.scss',
          'vendor/assets/stylesheets/foobar.scss'
        ]))
      end

      it 'flattens paths separately for js and css assets' do
        expect(
          targets(
            ['dist/css/foo.css', 'dist/js/foo.js'],
            ['dist/css/foo.css', 'dist/js/foo.js']
          )
        ).to eq(Paths.new([
          'vendor/assets/javascripts/foobar/foo.js',
          'vendor/assets/javascripts/foobar.js',
          'vendor/assets/stylesheets/foobar/foo.scss',
          'vendor/assets/stylesheets/foobar.scss'
        ]))
      end

      it 'preserves paths of other asset type if only one main' do
        expect(
          targets(
            ['dist/css/foo.css', 'dist/js/foo.js'],
            ['dist/css/foo.css']
          )
        ).to eq(Paths.new([
          'vendor/assets/javascripts/foobar/dist/js/foo.js',
          'vendor/assets/stylesheets/foobar/foo.scss',
          'vendor/assets/stylesheets/foobar.scss'
        ]))
      end

      it 'transforms all css files to scss ones to support asset urls' do
        expect(
          targets(['foo.css'])
        ).to eq(Paths.new([
          'vendor/assets/stylesheets/foobar/foo.scss'
        ]))
      end

      it 'it excludes all files in special directories like test or docs' do
        expect(
          targets([
            'test/foo.coffee',
            'test/foo/bar.js',
            'spec/foo.js',
            'perf/foo.js',
            'docs/README.md',
            'examples/foo/bar.js',
            'min/foo.js'
          ])
        ).to eq(Paths.new())
      end

      it 'it leaves main files in special directories' do
        expect(
          targets([
            'test/foo.coffee',
            'test/foo/bar.js',
            'spec/foo.js',
            'perf/foo.js',
            'docs/README.md',
            'examples/foo/bar.js',
            'min/bar/foo.js',
            'min/bar/foo-require.js'
          ], ['min/bar/foo.js'])
        ).to eq(Paths.new([
          'vendor/assets/javascripts/foobar/foo-require.js',
          'vendor/assets/javascripts/foobar/foo.js',
          'vendor/assets/javascripts/foobar.js'
        ]))
      end
    end

    context '#process_transformations!' do
      it 'transforms urls in css files' do
        source_file = Path.new('style.css')
        target_file = Path.new('style.scss')

        transformations = Hash[[
          [source_file, target_file],
          [Path.new('foo/bar.png'), Path.new('vendor/assets/images/foo.png')],
          [Path.new('foo/before.png'), Path.new('vendor/assets/images/before.png')],
          [Path.new('foo/around.png'), Path.new('vendor/assets/images/around.png')],
          [Path.new('foo/after.png'), Path.new('vendor/assets/images/after.png')],
          [Path.new('foo/spam.eot'), Path.new('vendor/assets/fonts/spam.eot')],
          [Path.new('foo/spam.woff'), Path.new('vendor/assets/fonts/spam.woff')],
          [Path.new('foo/spam.ttf'), Path.new('vendor/assets/fonts/spam.ttf')],
          [Path.new('foo/spam.otf'), Path.new('vendor/assets/fonts/spam.otf')],
          [Path.new('foo/spam.svg'), Path.new('vendor/assets/fonts/spam.svg')]
        ]]

        css_sample = <<-CSS.gsub(/^ {8}/, '')
        @font-family {
          src:url('foo/spam.eot'); /* IE9 Compat Modes */
          src: url('foo/spam.eot?#iefix') format('embedded-opentype'), /* IE6-IE8 */
               url('foo/spam.woff') format('woff'),url('foo/spam.ttf')  format('truetype'), /* Safari, Android, iOS */
               \n\nurl('foo/spam.otf')  format('opentype'),/**/url('foo/spam.svg#svgFontName') format('svg'); /* Legacy iOS */
          }
        }
        body{background-image:url(foo/bar.png)}
        body{background-image:url( foo/before.png)}
        body{background-image:url( foo/around.png )}
        body{background-image:url(foo/after.png )}
        CSS

        File.write('/tmp/style.css', css_sample)
        FileUtils.mkdir_p('/tmp/foo')
        File.write('/tmp/foo/bar.png', "BINARY")
        File.write('/tmp/foo/before.png', "BINARY")
        File.write('/tmp/foo/around.png', "BINARY")
        File.write('/tmp/foo/after.png', "BINARY")
        %w(eot woff ttf otf svg).each do |font_ext|
          File.write("/tmp/foo/spam.#{font_ext}", "BINARY")
        end

        Transformer.process_transformations!(transformations, '/tmp', '/tmp')
        actual_content = File.read('/tmp/style.scss')
        [
          'background-image:image-url("foo.png")',
          'background-image:image-url("before.png")',
          'background-image:image-url("around.png")',
          'background-image:image-url("after.png")',
          'src:font-url("spam.eot")',
          'src: font-url("spam.eot?#iefix") format(\'embedded-opentype\')',
          'font-url("spam.woff") format(\'woff\')',
          ',font-url("spam.ttf")  format(\'truetype\')',
          "\n\nfont-url(\"spam.otf\")  format('opentype')",
          '/**/font-url("spam.svg#svgFontName") format(\'svg\')',
        ].each do |content|
          expect(actual_content).to include(content)
        end
      end
    end

    context '#transform_relative_path' do
      it 'properly transforms relative path' do
        expect(Transformer.transform_relative_path(:images,
          Path.new('../images/image.png'), Path.new('dist/css/foobar.css'),
          Hash[[
            [Path.new('./dist/css/foobar.css'), Path.new('css/foobar.css')],
            [Path.new('./dist/images/image.png'), Path.new('vendor/assets/images/fiz/img.png')],
            [Path.new('./dist/image.png'), Path.new('vendor/assets/images/fuz/img.png')]
          ]]
        )).to eq(Path.new('fiz/img.png'))
      end
    end

    context '#transform_filename' do
      it 'leaves less extension' do
        filename = Transformer.transform_filename(
          'jquery.cookie.less'
        )

        expect(filename).to eq('jquery.cookie.less')
      end

      it 'leaves sass extension' do
        filename = Transformer.transform_filename(
          'jquery.cookie.sass'
        )

        expect(filename).to eq('jquery.cookie.sass')
      end

      it 'converts css extension to scss' do
        filename = Transformer.transform_filename(
          'jquery.cookie.css'
        )

        expect(filename).to eq('jquery.cookie.scss')
      end

      it 'leaves all non-custom extension' do
        filename = Transformer.transform_filename(
          'jquery.js.cookie.css.scss'
        )

        expect(filename).to eq('jquery.js.cookie.css.scss')
      end

      it 'also deals with paths' do
        filename = Transformer.transform_filename(
          '/foo/bar/jquery.cookie.sass'
        )

        expect(filename).to eq('/foo/bar/jquery.cookie.sass')
      end

      it 'deals with Path object' do
        filename = Transformer.transform_filename(
          Path.new('/jquery.cookie.sass')
        )

        expect(filename).to eq('/jquery.cookie.sass')
      end
    end
  end
end
