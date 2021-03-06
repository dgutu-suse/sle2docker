require_relative 'test_helper'

# rubocop:disable Metrics/LineLength, Style/MethodCallParentheses:
class PrebuiltImageTest < MiniTest::Test
  describe 'PrebuiltImage' do
    before do
      @options = { password: '' }
    end

    after do
      FakeFS::FileSystem.clear
    end

    describe 'listing' do
      it 'works when no pre-built image is available' do
        actual = Sle2Docker::PrebuiltImage.list
        expected = []
        assert_equal expected, actual
      end

      it 'lists the names of the available images' do
        FakeFS do
          expected = [
            'sles11sp3-docker.x86_64-1.0.0-Build1.3',
            'sles12-docker.x86_64-1.0.0-Build7.2'
          ]

          FileUtils.mkdir_p(Sle2Docker::PrebuiltImage::IMAGES_DIR)
          expected.each do |image|
            FileUtils.touch(
              File.join(
                Sle2Docker::PrebuiltImage::IMAGES_DIR,
                "#{image}.tar.xz"
              )
            )
          end

          actual = Sle2Docker::PrebuiltImage.list
          assert_equal expected, actual
        end
      end
    end

    describe 'activation' do
      it 'creates a Dockerfile and builds the image' do
        begin
          image = 'sles12-docker.x86_64-1.0.0-Build7.2'
          prebuilt_image = Sle2Docker::PrebuiltImage.new(image, @options)
          expected = <<EOF
FROM scratch
MAINTAINER "Flavio Castelli <fcastelli@suse.com>"

ADD sles12-docker.x86_64-1.0.0-Build7.2.tar.xz /
EOF

          tmp_dir = Dir.mktmpdir('sle2docker-test')
          prebuilt_image.create_dockerfile(tmp_dir)
          dockerfile = File.join(tmp_dir, 'Dockerfile')

          assert File.exist?(dockerfile)
          assert_equal(expected, File.read(dockerfile))
        ensure
          FileUtils.rm_rf(tmp_dir) if File.exist?(tmp_dir)
        end
      end

      it 'triggers docker build' do
        File.stubs(:exist?).returns(true)
        tmp_dir = '/foo'
        mocked_image = mock()
        mocked_image.expects(:tag)
                    .with('repo' => 'suse/sles12', 'tag' => '1.0.0')
                    .once
        mocked_image.expects(:tag)
                    .with('repo' => 'suse/sles12', 'tag' => 'latest')
                    .once

        prebuilt_image = Sle2Docker::PrebuiltImage.new(
          'sles12-docker.x86_64-1.0.0-Build7.2',
          @options
        )
        prebuilt_image.expects(:prepare_docker_build_root).once.returns(tmp_dir)
        prebuilt_image.expects(:verify_image).once
        Docker::Image.expects(:build_from_dir).with(tmp_dir).once.returns(mocked_image)
        FileUtils.expects(:rm_rf).with(tmp_dir).once

        prebuilt_image.activate
      end
    end
  end
end
