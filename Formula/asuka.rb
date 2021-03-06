class Asuka < Formula
  desc "Gemini Project client written in Rust with NCurses"
  homepage "https://git.sr.ht/~julienxx/asuka"
  url "https://git.sr.ht/~julienxx/asuka/archive/0.8.0.tar.gz"
  sha256 "c06dc528b8588be4922a7b4357f8e9701b1646db0828ccfcad3a5be178d31582"

  bottle do
    cellar :any_skip_relocation
    sha256 "e822cdbdf7c6eeaefabde6c69853ed5acdab7b959d44feff9e5c6eb44ea4b75c" => :catalina
    sha256 "95691f54ea6f8e5e218ec152b0d9685a4a8f4d59075207a1f75958333a174410" => :mojave
    sha256 "422e2efe84c94e78b3f1ab4bf9928d594c83e09b8ad1e32aabf04b17c2b8bb8a" => :high_sierra
  end

  depends_on "rust" => :build

  uses_from_macos "ncurses"

  def install
    system "cargo", "install", "--locked", "--root", prefix, "--path", "."
  end

  test do
    require "openssl"
    require "pty"

    system "openssl", "req", "-newkey", "rsa:2048",
           "-nodes", "-keyout", "localhost.key",
           "-nodes", "-x509", "-out", "localhost.crt",
           "-subj", "/CN=localhost"

    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.cert = OpenSSL::X509::Certificate.new(File.open("localhost.crt"))
    ssl_context.key = OpenSSL::PKey::RSA.new(File.open("localhost.key"))

    begin
      server = OpenSSL::SSL::SSLServer.new(TCPServer.new(1965), ssl_context)
      server_pid = fork do
        connection = server.accept
        msg = connection.gets
        assert_match "gemini://127.0.0.1/\r\n", msg
        connection.puts "20 text/plain\r\n"
        connection.puts "Hello world!"
        server.close
      end

      output, input, client_pid = PTY.spawn "#{bin}/asuka"
      sleep 1
      input.putc "g"
      sleep 1
      input.puts "gemini://127.0.0.1"
      output.gets

      Process.wait server_pid
    ensure
      Process.kill("TERM", client_pid)
    end
  end
end
