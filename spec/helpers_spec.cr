require "kemal"
require "openssl/hmac"
require "pg"
require "protodec/utils"
require "spec"
require "yaml"
require "../src/invidious/helpers/*"
require "../src/invidious/channels"
require "../src/invidious/comments"
require "../src/invidious/playlists"
require "../src/invidious/search"
require "../src/invidious/trending"
require "../src/invidious/users"

CONFIG = Config.from_yaml(File.open("config/config.example.yml"))

describe "Helper" do
  describe "#produce_channel_videos_url" do
    it "correctly produces url for requesting page `x` of a channel's videos" do
      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw").should eq("/browse_ajax?continuation=4qmFsgI8EhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaIEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0V4&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw", sort_by: "popular").should eq("/browse_ajax?continuation=4qmFsgJAEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaJEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0V4R0FFPQ%3D%3D&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw", page: 20).should eq("/browse_ajax?continuation=4qmFsgJAEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaJEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0l5TUE9PQ%3D%3D&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UC-9-kyTW8ZkZNDHQJ6FgpwQ", page: 20, sort_by: "popular").should eq("/browse_ajax?continuation=4qmFsgJAEhhVQy05LWt5VFc4WmtaTkRIUUo2Rmdwd1EaJEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0l5TUJnQg%3D%3D&gl=US&hl=en")
    end
  end

  describe "#produce_channel_search_continuation" do
    it "correctly produces token for searching a specific channel" do
      produce_channel_search_url("UCXuqSBlHAE6Xw-yeJA0Tunw", "", 100).should eq("4qmFsgJqEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaIEVnWnpaV0Z5WTJnd0FUZ0JZQUY2QkVkS2IxaTRBUUE9WgCaAilicm93c2UtZmVlZFVDWHVxU0JsSEFFNlh3LXllSkEwVHVud3NlYXJjaA%3D%3D")

      produce_channel_search_url("UCXuqSBlHAE6Xw-yeJA0Tunw", "По ожиशुपतिरपि子而時ஸ்றீனி", 0).should eq("4qmFsgKoARIYVUNYdXFTQmxIQUU2WHcteWVKQTBUdW53GiBFZ1p6WldGeVkyZ3dBVGdCWUFGNkJFZEJRVDI0QVFBPVo-0J_QviDQvtC20LjgpLbgpYHgpKrgpKTgpL_gpLDgpKrgpL_lrZDogIzmmYLgrrjgr43grrHgr4Dgrqngrr-aAilicm93c2UtZmVlZFVDWHVxU0JsSEFFNlh3LXllSkEwVHVud3NlYXJjaA%3D%3D")
    end
  end

  describe "#produce_channel_playlists_url" do
    it "correctly produces a /browse_ajax URL with the given UCID and cursor" do
      produce_channel_playlists_url("UCCj956IF62FbT7Gouszaj9w", "AIOkY9EQpi_gyn1_QrFuZ1reN81_MMmI1YmlBblw8j7JHItEFG5h7qcJTNd4W9x5Quk_CVZ028gW").should eq("/browse_ajax?continuation=4qmFsgLNARIYVUNDajk1NklGNjJGYlQ3R291c3phajl3GrABRWdsd2JHRjViR2x6ZEhNd0FqZ0JZQUZxQUxnQkFIcG1VVlZzVUdFeGF6VlNWa1ozWVZZNWJtVlhOSGhZTVVaNVVtNVdZVTFZU214VWFtZDRXREF4VG1KVmEzaFhWekZ6VVcxS2MyUjZhSEZPTUhCSlUxaFNSbEpyWXpGaFJHUjRXVEJ3VlZSdFVUQldlbXcwVGxaR01XRXhPVVJXYkc5M1RXcG9ibFozSUFFWUF3PT0%3D&gl=US&hl=en")
    end
  end

  describe "#extract_channel_playlists_cursor" do
    it "correctly extracts a playlists cursor from the given URL" do
      extract_channel_playlists_cursor("4qmFsgLRARIYVUNDajk1NklGNjJGYlQ3R291c3phajl3GrQBRWdsd2JHRjViR2x6ZEhNWUF5QUJNQUk0QVdBQmFnQjZabEZWYkZCaE1XczFVbFpHZDJGV09XNWxWelI0V0RGR2VWSnVWbUZOV0Vwc1ZHcG5lRmd3TVU1aVZXdDRWMWN4YzFGdFNuTmtlbWh4VGpCd1NWTllVa1pTYTJNeFlVUmtlRmt3Y0ZWVWJWRXdWbnBzTkU1V1JqRmhNVGxFVm14dmQwMXFhRzVXZDdnQkFBJTNEJTNE", false).should eq("AIOkY9EQpi_gyn1_QrFuZ1reN81_MMmI1YmlBblw8j7JHItEFG5h7qcJTNd4W9x5Quk_CVZ028gW")
    end
  end

  describe "#produce_playlist_continuation" do
    it "correctly produces ctoken for requesting index `x` of a playlist" do
      produce_playlist_continuation("UUCla9fZca4I7KagBtgRGnOw", 100).should eq("4qmFsgJNEhpWTFVVQ2xhOWZaY2E0STdLYWdCdGdSR25PdxoUQ0FGNkJsQlVPa05IVVElM0QlM0SaAhhVVUNsYTlmWmNhNEk3S2FnQnRnUkduT3c%3D")

      produce_playlist_continuation("UCCla9fZca4I7KagBtgRGnOw", 200).should eq("4qmFsgJLEhpWTFVVQ2xhOWZaY2E0STdLYWdCdGdSR25PdxoSQ0FKNkIxQlVPa05OWjBJJTNEmgIYVVVDbGE5ZlpjYTRJN0thZ0J0Z1JHbk93")

      produce_playlist_continuation("PL55713C70BA91BD6E", 100).should eq("4qmFsgJBEhRWTFBMNTU3MTNDNzBCQTkxQkQ2RRoUQ0FGNkJsQlVPa05IVVElM0QlM0SaAhJQTDU1NzEzQzcwQkE5MUJENkU%3D")
    end
  end

  describe "#produce_search_params" do
    it "correctly produces token for searching with specified filters" do
      produce_search_params.should eq("CAASAhABSAA%3D")

      produce_search_params(sort: "upload_date", content_type: "video").should eq("CAISAhABSAA%3D")

      produce_search_params(content_type: "playlist").should eq("CAASAhADSAA%3D")

      produce_search_params(sort: "date", content_type: "video", features: ["hd", "cc", "purchased", "hdr"]).should eq("CAISCxABIAEwAUgByAEBSAA%3D")

      produce_search_params(content_type: "channel").should eq("CAASAhACSAA%3D")
    end
  end

  describe "#extract_comment_cursor" do
    it "correctly extracts a comment cursor from a given continuation" do
      extract_comment_cursor("EiYSC2tKUVA3a2l3NUZrwAEByAEB4AEBogINKP___________wFAABgGMpwFCoYFQURTSl9pM1RqN1VlZ3dBd1daZkk4TmNiZ0djLVp0NFZEaW1BUGZwWHlPNDhuYUFxa3BsOXZYTk41OWpGXzNGRkVZeVpJOHRGWWpla0w1Z2ktcjhLdGFhcmduMDFxTUpsQ19QN2NaLWU5VGxxbTgzeUN6QVFHSUVtMGlMbUs5ZmVNOUVmNVo2S24xclpPRmlOdkxJS3JIUlJhWS10dkFNdzBDb0R3UWxiSXdpNDAzNkNCQ0ZXY2syemh1VHBsdEVUa2RmRHVrYVdkNnR1X1F4dkdnMGRkeEMydnNuVnlsQ1lJSUliWjAwMk1UTmpsbWJ5ejNKeGVybHJoa1drNW9kODZhOS16RVBPMjRHVzRKZnJlZEFvdGtzRmtCUUx5RWNRbkxRdHVyMHNwbGNmLUswZUttTlZkbk1DY1JVUF9LaU8tdVk4Qmg4RmtCa2RwMTFhVW10R0tzMWM0VjZXVkwwc29TallQc0VGLUF0LWlEVENJVXRNT1RLZklMblJ2V2NJclJvWndUNHA2MXFFMnhuN01CSFVJMzJJRjhJN2pKanh4a2o3ekMtUXBuT0xFdUNGOGJlN29kekFDa2VfTzVZNnpHM1FzN0lDM3NvV0NFbVJiLXlPNzB0ZDlXS3lXc25UNTJqM0FVT3hiQW16NU1EeU9qUVN3SERLNlFmaVh6N3ZjbGZnWEgxSUlqVmFCVUc3bkhlZkFOMlNoZ1BnN1hwaHBrV0FUdUtnRjNtRnBNRmViTFp2bHVPQ1k1WkgxVTh5LWV1ZnN5UUhxQkZJVlh0Mkg1NEFVa0xZeGdORmJTY0dfaEE4dEswV0JwdkdGUmE0V2dmT3NsNjlRSmRISTBKbWlOeS1rdyIPIgtrSlFQN2tpdzVGazAAKCg%3D").should eq("ADSJ_i3Tj7UegwAwWZfI8NcbgGc-Zt4VDimAPfpXyO48naAqkpl9vXNN59jF_3FFEYyZI8tFYjekL5gi-r8Ktaargn01qMJlC_P7cZ-e9Tlqm83yCzAQGIEm0iLmK9feM9Ef5Z6Kn1rZOFiNvLIKrHRRaY-tvAMw0CoDwQlbIwi4036CBCFWck2zhuTpltETkdfDukaWd6tu_QxvGg0ddxC2vsnVylCYIIIbZ002MTNjlmbyz3JxerlrhkWk5od86a9-zEPO24GW4JfredAotksFkBQLyEcQnLQtur0splcf-K0eKmNVdnMCcRUP_KiO-uY8Bh8FkBkdp11aUmtGKs1c4V6WVL0soSjYPsEF-At-iDTCIUtMOTKfILnRvWcIrRoZwT4p61qE2xn7MBHUI32IF8I7jJjxxkj7zC-QpnOLEuCF8be7odzACke_O5Y6zG3Qs7IC3soWCEmRb-yO70td9WKyWsnT52j3AUOxbAmz5MDyOjQSwHDK6QfiXz7vclfgXH1IIjVaBUG7nHefAN2ShgPg7XphpkWATuKgF3mFpMFebLZvluOCY5ZH1U8y-eufsyQHqBFIVXt2H54AUkLYxgNFbScG_hA8tK0WBpvGFRa4WgfOsl69QJdHI0JmiNy-kw")

      extract_comment_cursor("EiYSC2tKUVA3a2l3NUZrwAEByAEB4AEBogINKP___________wFAABgGMo4DCvgCQURTSl9pMEhLLWg2SGRybURYZV93VXA3b1VuVmhFZlJtcUNndUxPaEtTNnlONURSdTAxZ2RQUVBEQkw3ZFVJci1fNDRPc3dVUDF0WjE1YVczMUJjN1JNb2ZCdzc0cDhyVnFLcWVzUDFPZnhOXzhDRlV2ZHo0aDlvalM1UzFJbjEzVGVXQkx5TmxlcHhRSy00Ymhwd1I0Q3FIN2I1YlBvMkw2ZE8xdklXc3VsRmJQQXpQb29XTkhPdGlHdlRsbmFybEl2VFBPb3BzcTFsd3RUanhSZ25yU0d2SlhscHFPeUpZb0tyR01Cam5nREk2ZFMxcTU2UEt1ajlvbTc4WTFvckhiZzhaOEZrNG54NUFDd2lCSjYtLTBoOXhpNnpSMi1oeTRnTTlGWnFIeHU1QlgwQzBCczJ0WEJ4V1BoTWVPVUtPVjh6UVFaOTNXdTlhc284THdPMVVJZmtkdWgxSTVMY0NaWUlPLXd1c1UxcnN5MWV5ekQtZ0NBTiIPIgtrSlFQN2tpdzVGazAAKCg%3D").should eq("ADSJ_i0HK-h6HdrmDXe_wUp7oUnVhEfRmqCguLOhKS6yN5DRu01gdPQPDBL7dUIr-_44OswUP1tZ15aW31Bc7RMofBw74p8rVqKqesP1OfxN_8CFUvdz4h9ojS5S1In13TeWBLyNlepxQK-4bhpwR4CqH7b5bPo2L6dO1vIWsulFbPAzPooWNHOtiGvTlnarlIvTPOopsq1lwtTjxRgnrSGvJXlpqOyJYoKrGMBjngDI6dS1q56PKuj9om78Y1orHbg8Z8Fk4nx5ACwiBJ6--0h9xi6zR2-hy4gM9FZqHxu5BX0C0Bs2tXBxWPhMeOUKOV8zQQZ93Wu9aso8LwO1UIfkduh1I5LcCZYIO-wusU1rsy1eyzD-gCAN")
    end
  end

  describe "#produce_comment_continuation" do
    it "correctly produces a continuation token for comments" do
      produce_comment_continuation("_cE8xSu6swE", "ADSJ_i2qvJeFtL0htmS5_K5Ctj3eGFVBMWL9Wd42o3kmUL6_mAzdLp85-liQZL0mYr_16BhaggUqX652Sv9JqV6VXinShSP-ZT6rL4NolPBaPXVtJsO5_rA_qE3GubAuLFw9uzIIXU2-HnpXbdgPLWTFavfX206hqWmmpHwUOrmxQV_OX6tYkM3ux3rPAKCDrT8eWL7MU3bLiNcnbgkW8o0h8KYLL_8BPa8LcHbTv8pAoNkjerlX1x7K4pqxaXPoyz89qNlnh6rRx6AXgAzzoHH1dmcyQ8CIBeOHg-m4i8ZxdX4dP88XWrIFg-jJGhpGP8JUMDgZgavxVx225hUEYZMyrLGler5em4FgbG62YWC51moLDLeYEA").should eq("EkMSC19jRTh4U3U2c3dFyAEA4AEBogINKP___________wFAAMICHQgEGhdodHRwczovL3d3dy55b3V0dWJlLmNvbSIAGAYyjAMK9gJBRFNKX2kycXZKZUZ0TDBodG1TNV9LNUN0ajNlR0ZWQk1XTDlXZDQybzNrbVVMNl9tQXpkTHA4NS1saVFaTDBtWXJfMTZCaGFnZ1VxWDY1MlN2OUpxVjZWWGluU2hTUC1aVDZyTDROb2xQQmFQWFZ0SnNPNV9yQV9xRTNHdWJBdUxGdzl1eklJWFUyLUhucFhiZGdQTFdURmF2ZlgyMDZocVdtbXBId1VPcm14UVZfT1g2dFlrTTN1eDNyUEFLQ0RyVDhlV0w3TVUzYkxpTmNuYmdrVzhvMGg4S1lMTF84QlBhOExjSGJUdjhwQW9Oa2plcmxYMXg3SzRwcXhhWFBveXo4OXFObG5oNnJSeDZBWGdBenpvSEgxZG1jeVE4Q0lCZU9IZy1tNGk4WnhkWDRkUDg4WFdySUZnLWpKR2hwR1A4SlVNRGdaZ2F2eFZ4MjI1aFVFWVpNeXJMR2xlcjVlbTRGZ2JHNjJZV0M1MW1vTERMZVlFQSIPIgtfY0U4eFN1NnN3RTAAKBQ%3D")

      produce_comment_continuation("_cE8xSu6swE", "ADSJ_i1yz21HI4xrtsYXVC-2_kfZ6kx1yjYQumXAAxqH3CAd7ZxKxfLdZS1__fqhCtOASRbbpSBGH_tH1J96Dxux-Qfjk-lUbupMqv08Q3aHzGu7p70VoUMHhI2-GoJpnbpmcOxkGzeIuenRS_ym2Y8fkDowhqLPFgsS0n4djnZ2UmC17F3Ch3N1S1UYf1ZVOc991qOC1iW9kJDzyvRQTWCPsJUPneSaAKW-Rr97pdesOkR4i8cNvHZRnQKe2HEfsvlJOb2C3lF1dJBfJeNfnQYeh5hv6_fZN7bt3-JL1Xk3Qc9NXNxmmbDpwAC_yFR8dthFfUJdyIO9Nu1D79MLYeR-H5HxqUJokkJiGIz4lTE_CXXbhAI").should eq("EkMSC19jRTh4U3U2c3dFyAEA4AEBogINKP___________wFAAMICHQgEGhdodHRwczovL3d3dy55b3V0dWJlLmNvbSIAGAYyiQMK8wJBRFNKX2kxeXoyMUhJNHhydHNZWFZDLTJfa2ZaNmt4MXlqWVF1bVhBQXhxSDNDQWQ3WnhLeGZMZFpTMV9fZnFoQ3RPQVNSYmJwU0JHSF90SDFKOTZEeHV4LVFmamstbFVidXBNcXYwOFEzYUh6R3U3cDcwVm9VTUhoSTItR29KcG5icG1jT3hrR3plSXVlblJTX3ltMlk4ZmtEb3docUxQRmdzUzBuNGRqbloyVW1DMTdGM0NoM04xUzFVWWYxWlZPYzk5MXFPQzFpVzlrSkR6eXZSUVRXQ1BzSlVQbmVTYUFLVy1Scjk3cGRlc09rUjRpOGNOdkhaUm5RS2UySEVmc3ZsSk9iMkMzbEYxZEpCZkplTmZuUVllaDVodjZfZlpON2J0My1KTDFYazNRYzlOWE54bW1iRHB3QUNfeUZSOGR0aEZmVUpkeUlPOU51MUQ3OU1MWWVSLUg1SHhxVUpva2tKaUdJejRsVEVfQ1hYYmhBSSIPIgtfY0U4eFN1NnN3RTAAKBQ%3D")

      produce_comment_continuation("29-q7YnyUmY", "").should eq("EkMSCzI5LXE3WW55VW1ZyAEA4AEBogINKP___________wFAAMICHQgEGhdodHRwczovL3d3dy55b3V0dWJlLmNvbSIAGAYyFQoAIg8iCzI5LXE3WW55VW1ZMAAoFA%3D%3D")

      produce_comment_continuation("CvFH_6DNRCY", "").should eq("EkMSC0N2RkhfNkROUkNZyAEA4AEBogINKP___________wFAAMICHQgEGhdodHRwczovL3d3dy55b3V0dWJlLmNvbSIAGAYyFQoAIg8iC0N2RkhfNkROUkNZMAAoFA%3D%3D")
    end
  end

  describe "#produce_comment_reply_continuation" do
    it "correctly produces a continuation token for replies to a given comment" do
      produce_comment_reply_continuation("cIHQWOoJeag", "UCq6VFHwMzcMXbuKyG7SQYIg", "Ugx1IP_wGVv3WtGWcdV4AaABAg").should eq("EiYSC2NJSFFXT29KZWFnwAEByAEB4AEBogINKP___________wFAABgGMk0aSxIaVWd4MUlQX3dHVnYzV3RHV2NkVjRBYUFCQWciAggAKhhVQ3E2VkZId016Y01YYnVLeUc3U1FZSWcyC2NJSFFXT29KZWFnQAFICg%3D%3D")

      produce_comment_reply_continuation("cIHQWOoJeag", "UCq6VFHwMzcMXbuKyG7SQYIg", "Ugza62y_TlmTu9o2RfF4AaABAg").should eq("EiYSC2NJSFFXT29KZWFnwAEByAEB4AEBogINKP___________wFAABgGMk0aSxIaVWd6YTYyeV9UbG1UdTlvMlJmRjRBYUFCQWciAggAKhhVQ3E2VkZId016Y01YYnVLeUc3U1FZSWcyC2NJSFFXT29KZWFnQAFICg%3D%3D")

      produce_comment_reply_continuation("_cE8xSu6swE", "UC1AZY74-dGVPe6bfxFwwEMg", "UgyBUaRGHB9Jmt1dsUZ4AaABAg").should eq("EiYSC19jRTh4U3U2c3dFwAEByAEB4AEBogINKP___________wFAABgGMk0aSxIaVWd5QlVhUkdIQjlKbXQxZHNVWjRBYUFCQWciAggAKhhVQzFBWlk3NC1kR1ZQZTZiZnhGd3dFTWcyC19jRTh4U3U2c3dFQAFICg%3D%3D")
    end
  end

  describe "#produce_channel_community_continuation" do
    it "correctly produces a continuation token for a channel community" do
      produce_channel_community_continuation("UCCj956IF62FbT7Gouszaj9w", "Egljb21tdW5pdHm4").should eq("4qmFsgIsEhhVQ0NqOTU2SUY2MkZiVDdHb3VzemFqOXcaEEVnbGpiMjF0ZFc1cGRIbTQ%3D")
      produce_channel_community_continuation("UCCj956IF62FbT7Gouszaj9w", "Egljb21tdW5pdHm4AQCqAyQaIBIaVWd3cE9NQmVwWEdjclhsUHg2WjRBYUFCQ1FIZGgDKAA%3D").should eq("4qmFsgJmEhhVQ0NqOTU2SUY2MkZiVDdHb3VzemFqOXcaSkVnbGpiMjF0ZFc1cGRIbTRBUUNxQXlRYUlCSWFWV2QzY0U5TlFtVndXRWRqY2xoc1VIZzJXalJCWVVGQ1ExRklaR2dES0FBJTNE")

      produce_channel_community_continuation("UC-lHJZR3Gqxm24_Vd_AJ5Yw", "Egljb21tdW5pdHm4AQCqAyQaIBIaVWd5RTI2NW1rUkk2cE9uS21nbDRBYUFCQ1FIZGgDKAA%3D").should eq("4qmFsgJmEhhVQy1sSEpaUjNHcXhtMjRfVmRfQUo1WXcaSkVnbGpiMjF0ZFc1cGRIbTRBUUNxQXlRYUlCSWFWV2Q1UlRJMk5XMXJVa2syY0U5dVMyMW5iRFJCWVVGQ1ExRklaR2dES0FBJTNE")
      produce_channel_community_continuation("UC-lHJZR3Gqxm24_Vd_AJ5Yw", "Egljb21tdW5pdHm4AQCqA-cOCsAOUVVSVFNsOXBNWEYxYlVablFXaGFiWFJNTW5WM1ZHSXdPVU5EWTNoeFJWWlVjRWRGVTBOa1prTktjVUoyWjBZemNEZHRPV2cwV1hWbVJtaFVPWFJwVjJaUU4xTXlNRWRaYlZwSVFUa3dlak5pTUV0dll6QkRVMlpsWHpoVFdUbHFSR0o1YkRkM1kydEhMVTVwWDFCdFdXOUhjR0Z6ZEMxbldVcEhUMjkzUm1saGRXSkViVmR6ZFhwd1QxTnpOME54TW5KUloxQlBkME5QU1VWVWMybHlNbFZvUVV0NlVIZFVhMVV5UzNWUmJHRldkRmszU1dKd1pVUllVMkZFVG1aV1ZsRnVUMGhsZFd0T01sVndTbGd3TkhweVdDMVBTRUphV25GNk5Yb3dYMWRCVTFnMlltODBPRmhIV205WlQwNW1YMjV1UlVKTWNucHNNSGR5Y1hKaFltUkVkblJYZG1Kc1FVaHFUV3BwTkc5R1pUQkVlbGw2ZHpSM2FISlBTSFJoYjJGbVMwNTBiV1pxV2pCSVNWWnZTalpRT0RoclVGVmhia1p5VFhsaWFTMVBjREZZV1dSTFdERkZjSHB0ZUhseWFtRXdNR1JmTkhOWmFEVlZTbVZ1ZUVkRU1XRlFhbU4xVERabk4wdDVSSGxHU2xsT1VEQlJXR1ZLTUhGM1UwWkJTSE5oWkRWQ2NXZHNaMFpqYW1ST1YxZFlhMDVOVUZSSFZWVktRekZSYVhodlUxTm1SV1EwTUdsdWNEWXlPV1YwUjNkcGFVcEVTM040YUZadmRXbHJhblkyZFdFelNHWXpUV3hMYURCa2JIRTFSblJ4Wms4NU1XbGtOM0pHYjBGeU4xZFJNMU5qYkZCd05rZE9jV1JqT1hGRGIyNU5Xak5TUlhkemFsUXRObGt4UWxkUE16ZGFaRTlxVGtaZlIweEhRbXRNWXpCWE9GUjNOMHBsYVhwS2RtSlZkMmxGTVhCbVNIWkdkVTFJY0MxbFdYSkVZM0V0ZFROWWRtVlFlV3hhYlVKMmVreGZUMGxOU2xaSlRFTlBZMVpEUjFwd1RHZFhZMmhIYVVKakxUSmFabXd0U1RNeFJEWkhlSGhYTkhOMU1GZGhOMjFCVlVnNGNFTlJXSGx2WW5ScWNUaHZXWGxKT1d0TVRXc3lRMWc0Um5wU2JEVjBlRGxpTW5vMVRYaEtkelExY201S1JHSmZkamhmTlhOWmRGYzRjak5FVVdkMlpXVnNRWEJyZW5OdFpHcEljVGhWYzFsZkxWa3dRVTkyTVZVMmIyMTNVeTFLVEUxeFIwUldRbmc0VEdsTlpGVktjVmxzTkZGa1UwazFabE0wZUhsRk5WZ3lWR0ZaYzJadlYyaHRPRFpzTjNCT1dHRnBiMHhUVDBkMmRuZFVOMlptVm05dWIwRTFZVkZuYldKNmIwMUNaMng2VGkxSk56bHhXV3BJVGt4RFYwVllUM05pTVcwemRHc3lUVWN6TVVKcVRHdElNVWg1YmtKQmVrbFNVMnczZEVKUlJGOUlNVWRyZERsbFJraHVYekJXZUhGbE1rTTBlVE40YVU1T1pFcGpVMkpFZFMxWVdITjNTMnhWVjJwYVgzVXRXbGcwZG5OSE1qUXpYMlJHTVhSV1kxWkZRMlZwU25OdVlXTkdVek5wVUd4b2FUbDVSRVp4YVhsbFRqbG1aRWxYVFZCMVFWbG9OMEl3TW5KV1JUVjRkREJLZG5obmJGZHhSVlY1ZWpjMFIyeGlZemRIVmkxeFpESmlaMnhFZGxkcVRuSjZNVEZWUkRWamVIQlFkRk5DVmtSU2RITlRaSGhWZG05WE9VUkNhWEYwTm1kSFRtb3RNV1pNYlhSeVJWTnJhRWhIVDB0SU0yVkxUbFZ2V1VGNlJTMDJialJZYkRKdFFUVnJhRVJ4WmpjeFptcERNR001UmpkM2QwNW1VRXd5YUZCZlEwWjFSbEUzY0doRk5ISkZZMWxTTWs5d2RXRnhiRzFrYjBVMmIxWkJaRzkyU2xneFZWOXNiMDVWWkUxRFJ6QjBjWGhpVjBVMldYY3pTUzF4UVcxa1RuZEJRVGRvWVZFNGNsSTBaVUl0UmxacVdETnJXazVLY21aRk9HVndRbWxqUjB0blRFZEZVR3N6YzJOclkwSTNlVlZZVEdkcE1YQkdiMHAyZVU1aGRVZFdVblJQYVhaQlZtdHZSa0UzTFU1Sk1XaFJRMUpMV2kxSWJ6WkxjWEkxZGtSTWJsOVdUa0ZFVmpKZmMwUlFWV3gwUTJ0TFRsbDJaM2gxZFVOSVkzbEVORUpRZVUxMVREQnpOMVowWDI1MWRrVmlUMU54TkRkUk5rVjViMEpRTUZGNmR6RlJSR2RxY1U1eVgwNTBjMDkxWm14R2NUVjBlRkJGT1dGVmFXeFJTMEZYYldwQlVVbHNOVmgwZERZdGFFRlViMWxmUjFWc1EycG1WVkJQV0hkcFVRPT0aIBIaVWd5RTI2NW1rUkk2cE9uS21nbDRBYUFCQ1FIZGgDKGM%3D").should eq("4qmFsgKXFBIYVUMtbEhKWlIzR3F4bTI0X1ZkX0FKNVl3GvoTRWdsamIyMXRkVzVwZEhtNEFRQ3FBLWNPQ3NBT1VWVlNWRk5zT1hCTldFWXhZbFZhYmxGWGFHRmlXRkpOVFc1V00xWkhTWGRQVlU1RVdUTm9lRkpXV2xWalJXUkdWVEJPYTFwclRrdGpWVW95V2pCWmVtTkVaSFJQVjJjd1YxaFdiVkp0YUZWUFdGSndWakphVVU0eFRYbE5SV1JhWWxad1NWRlVhM2RsYWs1cFRVVjBkbGw2UWtSVk1scHNXSHBvVkZkVWJIRlNSMG8xWWtSa00xa3lkRWhNVlRWd1dERkNkRmRYT1VoalIwWjZaRU14YmxkVmNFaFVNamt6VW0xc2FHUlhTa1ZpVm1SNlpGaHdkMVF4VG5wT01FNTRUVzVLVWxveFFsQmtNRTVRVTFWV1ZXTXliSGxOYkZadlVWVjBObFZJWkZWaE1WVjVVek5XVW1KSFJsZGtSbXN6VTFkS2QxcFZVbGxWTWtaRlZHMWFWMVpzUm5WVU1HaHNaRmQwVDAxc1ZuZFRiR2QzVGtod2VWZERNVkJUUlVwaFYyNUdOazVZYjNkWU1XUkNWVEZuTWxsdE9EQlBSbWhJVjIwNVdsUXdOVzFZTWpWMVVsVktUV051Y0hOTlNHUjVZMWhLYUZsdFVrVmtibEpZWkcxS2MxRlZhSEZVVjNCd1RrYzVSMXBVUWtWbGJHdzJaSHBTTTJGSVNsQlRTRkpvWWpKR2JWTXdOVEJpVjFweFYycENTVk5XV25aVGFscFJUMFJvY2xWR1ZtaGlhMXA1VkZoc2FXRlRNVkJqUkVaWlYxZFNURmRFUmtaalNIQjBaVWhzZVdGdFJYZE5SMUptVGtoT1dtRkVWbFpUYlZaMVpVVmtSVTFYUmxGaGJVNHhWRVJhYms0d2REVlNTR3hIVTJ4c1QxVkVRbEpYUjFaTFRVaEdNMVV3V2tKVFNFNW9Xa1JXUTJOWFpITmFNRnBxWVcxU1QxWXhaRmxoTURWT1ZVWlNTRlpXVmt0UmVrWlNZVmhvZGxVeFRtMVNWMUV3VFVkc2RXTkVXWGxQVjFZd1VqTmtjR0ZWY0VWVE0wNDBZVVphZG1SWGJISmhibGt5WkZkRmVsTkhXWHBVVjNoTVlVUkNhMkpJUlRGU2JsSjRXbXM0TlUxWGJHdE9NMHBIWWpCR2VVNHhaRkpOTVU1cVlrWkNkMDVyWkU5alYxSnFUMWhHUkdJeU5VNVhhazVUVWxoa2VtRnNVWFJPYkd0NFVXeGtVRTE2WkdGYVJUbHhWR3RhWmxJd2VFaFJiWFJOV1hwQ1dFOUdVak5PTUhCc1lWaHdTMlJ0U2xaa01teEdUVmhDYlZOSVdrZGtWVEZKWTBNeGJGZFlTa1ZaTTBWMFpGUk9XV1J0VmxGbFYzaGhZbFZLTW1WcmVHWlVNR3hPVTJ4YVNsUkZUbEJaTVZwRVVqRndkMVJIWkZoWk1taElZVlZLYWt4VVNtRmFiWGQwVTFSTmVGSkVXa2hsU0doWVRraE9NVTFHWkdoT01qRkNWbFZuTkdORlRsSlhTR3gyV1c1U2NXTlVhSFpYV0d4S1QxZDBUVlJYYzNsUk1XYzBVbTV3VTJKRVZqQmxSR3hwVFc1dk1WUllhRXRrZWxFeFkyMDFTMUpIU21aa2FtaG1UbGhPV21SR1l6UmphazVGVlZka01scFhWbk5SV0VKeVpXNU9kRnBIY0VsalZHaFdZekZzWmt4V2EzZFJWVGt5VFZaVk1tSXlNVE5WZVRGTFZFVXhlRkl3VWxkUmJtYzBWRWRzVGxwR1ZrdGpWbXh6VGtaR2ExVXdhekZhYkUwd1pVaHNSazVXWjNsV1IwWmFZekphZGxZeWFIUlBSRnB6VGpOQ1QxZEhSbkJpTUhoVVZEQmtNbVJ1WkZWT01scHRWbTA1ZFdJd1JURlpWa1p1WWxkS05tSXdNVU5hTW5nMlZHa3hTazU2YkhoWFYzQkpWR3Q0UkZZd1ZsbFVNMDVwVFZjd2VtUkhjM2xVVldONlRWVktjVlJIZEVsTlZXZzFZbXRLUW1WcmJGTlZNbmN6WkVWS1VsSkdPVWxOVldSeVpFUnNiRkpyYUhWWWVrSlhaVWhHYkUxclRUQmxWRTQwWVZVMVQxcEZjR3BWTWtwRlpGTXhXVmRJVGpOVE1uaFdWakp3WVZnelZYUlhiR2N3Wkc1T1NFMXFVWHBZTWxKSFRWaFNWMWt4V2taUk1sWndVMjVPZFZsWFRrZFZlazV3VlVkNGIyRlViRFZTUlZwNFlWaHNiRlJxYkcxYVJXeFlWRlpDTVZGV2JHOU9NRWwzVFc1S1YxSlVWalJrUkVKTFpHNW9ibUpHWkhoU1ZsWTFaV3BqTUZJeWVHbFplbVJJVm1reGVGcEVTbWxhTW5oRlpHeGtjVlJ1U2paTlZFWldVa1JXYW1WSVFsRmtSazVEVm10U1UyUklUbFJhU0doV1pHMDVXRTlWVWtOaFdFWXdUbTFrU0ZSdGIzUk5WMXBOWWxoU2VWSldUbkpoUldoSVZEQjBTVTB5Vmt4VWJGWjJWMVZHTmxKVE1ESmlhbEpaWWtSS2RGRlVWbkpoUlZKNFdtcGplRnB0Y0VSTlIwMDFVbXBrTTJRd05XMVZSWGQ1WVVaQ1psRXdXakZTYkVVelkwZG9SazVJU2taWk1XeFRUV3M1ZDJSWFJuaGlSekZyWWpCVk1tSXhXa0phUnpreVUyeG5lRlpXT1hOaU1EVldXa1V4UkZKNlFqQmpXR2hwVmpCVk1sZFlZM3BUVXpGNFVWY3hhMVJ1WkVKUlZHUnZXVlpGTkdOc1NUQmFWVWwwVW14YWNWZEVUbkpYYXpWTFkyMWFSazlIVm5kUmJXeHFVakIwYmxSRlpFWlZSM042WXpKT2Nsa3dTVE5sVmxaWlZFZGtjRTFZUWtkaU1IQXlaVlUxYUdSVlpGZFZibEpRWVZoYVFsWnRkSFpTYTBVelRGVTFTazFYYUZKUk1VcE1WMmt4U1dKNldreGpXRWt4Wkd0U1RXSnNPVmRVYTBaRlZtcEtabU13VWxGV1YzZ3dVVEowVEZSc2JESmFNMmd4WkZWT1NWa3piRVZPUlVwUlpWVXhNVlJFUW5wT01Wb3dXREkxTVdSclZtbFVNVTU0VGtSa1VrNXJWalZpTUVwUlRVWkdObVI2UmxKU1IyUnhZMVUxZVZnd05UQmpNRGt4V20xNFIyTlVWakJsUmtKR1QxZEdWbUZYZUZKVE1FWllZbGR3UWxWVmJITk9WbWd3WkVSWmRHRkZSbFZpTVd4bVVqRldjMUV5Y0cxV1ZrSlFWMGhrY0ZWUlBUMGFJQklhVldkNVJUSTJOVzFyVWtrMmNFOXVTMjFuYkRSQllVRkNRMUZJWkdnREtHTSUzRA%3D%3D")
    end
  end

  describe "#extract_channel_community_cursor" do
    it "correctly extracts a community cursor from a given continuation" do
      extract_channel_community_cursor("4qmFsgIsEhhVQ0NqOTU2SUY2MkZiVDdHb3VzemFqOXcaEEVnbGpiMjF0ZFc1cGRIbTQ%3D").should eq("Egljb21tdW5pdHk=")
      extract_channel_community_cursor("4qmFsgJoEhhVQ0NqOTU2SUY2MkZiVDdHb3VzemFqOXcaTEVnbGpiMjF0ZFc1cGRIbTRBUUNxQXlRYUlCSWFWV2QzY0U5TlFtVndXRWRqY2xoc1VIZzJXalJCWVVGQ1ExRklaR2dES0FBJTI1M0Q%3D").should eq("Egljb21tdW5pdHm4AQCqAyQaIEhkaAMSGlVnd3BPTUJlcFhHY3JYbFB4Nlo0QWFBQkNRKAA=")

      extract_channel_community_cursor("4qmFsgJoEhhVQy1sSEpaUjNHcXhtMjRfVmRfQUo1WXcaTEVnbGpiMjF0ZFc1cGRIbTRBUUNxQXlRYUlCSWFWV2Q1UlRJMk5XMXJVa2syY0U5dVMyMW5iRFJCWVVGQ1ExRklaR2dES0FBJTI1M0Q%3D").should eq("Egljb21tdW5pdHm4AQCqAyQaIEhkaAMSGlVneUUyNjVta1JJNnBPbkttZ2w0QWFBQkNRKAA=")
      extract_channel_community_cursor("4qmFsgKZFBIYVUMtbEhKWlIzR3F4bTI0X1ZkX0FKNVl3GvwTRWdsamIyMXRkVzVwZEhtNEFRQ3FBLWNPQ3NBT1VWVlNWRk5zT1hCTldFWXhZbFZhYmxGWGFHRmlXRkpOVFc1V00xWkhTWGRQVlU1RVdUTm9lRkpXV2xWalJXUkdWVEJPYTFwclRrdGpWVW95V2pCWmVtTkVaSFJQVjJjd1YxaFdiVkp0YUZWUFdGSndWakphVVU0eFRYbE5SV1JhWWxad1NWRlVhM2RsYWs1cFRVVjBkbGw2UWtSVk1scHNXSHBvVkZkVWJIRlNSMG8xWWtSa00xa3lkRWhNVlRWd1dERkNkRmRYT1VoalIwWjZaRU14YmxkVmNFaFVNamt6VW0xc2FHUlhTa1ZpVm1SNlpGaHdkMVF4VG5wT01FNTRUVzVLVWxveFFsQmtNRTVRVTFWV1ZXTXliSGxOYkZadlVWVjBObFZJWkZWaE1WVjVVek5XVW1KSFJsZGtSbXN6VTFkS2QxcFZVbGxWTWtaRlZHMWFWMVpzUm5WVU1HaHNaRmQwVDAxc1ZuZFRiR2QzVGtod2VWZERNVkJUUlVwaFYyNUdOazVZYjNkWU1XUkNWVEZuTWxsdE9EQlBSbWhJVjIwNVdsUXdOVzFZTWpWMVVsVktUV051Y0hOTlNHUjVZMWhLYUZsdFVrVmtibEpZWkcxS2MxRlZhSEZVVjNCd1RrYzVSMXBVUWtWbGJHdzJaSHBTTTJGSVNsQlRTRkpvWWpKR2JWTXdOVEJpVjFweFYycENTVk5XV25aVGFscFJUMFJvY2xWR1ZtaGlhMXA1VkZoc2FXRlRNVkJqUkVaWlYxZFNURmRFUmtaalNIQjBaVWhzZVdGdFJYZE5SMUptVGtoT1dtRkVWbFpUYlZaMVpVVmtSVTFYUmxGaGJVNHhWRVJhYms0d2REVlNTR3hIVTJ4c1QxVkVRbEpYUjFaTFRVaEdNMVV3V2tKVFNFNW9Xa1JXUTJOWFpITmFNRnBxWVcxU1QxWXhaRmxoTURWT1ZVWlNTRlpXVmt0UmVrWlNZVmhvZGxVeFRtMVNWMUV3VFVkc2RXTkVXWGxQVjFZd1VqTmtjR0ZWY0VWVE0wNDBZVVphZG1SWGJISmhibGt5WkZkRmVsTkhXWHBVVjNoTVlVUkNhMkpJUlRGU2JsSjRXbXM0TlUxWGJHdE9NMHBIWWpCR2VVNHhaRkpOTVU1cVlrWkNkMDVyWkU5alYxSnFUMWhHUkdJeU5VNVhhazVUVWxoa2VtRnNVWFJPYkd0NFVXeGtVRTE2WkdGYVJUbHhWR3RhWmxJd2VFaFJiWFJOV1hwQ1dFOUdVak5PTUhCc1lWaHdTMlJ0U2xaa01teEdUVmhDYlZOSVdrZGtWVEZKWTBNeGJGZFlTa1ZaTTBWMFpGUk9XV1J0VmxGbFYzaGhZbFZLTW1WcmVHWlVNR3hPVTJ4YVNsUkZUbEJaTVZwRVVqRndkMVJIWkZoWk1taElZVlZLYWt4VVNtRmFiWGQwVTFSTmVGSkVXa2hsU0doWVRraE9NVTFHWkdoT01qRkNWbFZuTkdORlRsSlhTR3gyV1c1U2NXTlVhSFpYV0d4S1QxZDBUVlJYYzNsUk1XYzBVbTV3VTJKRVZqQmxSR3hwVFc1dk1WUllhRXRrZWxFeFkyMDFTMUpIU21aa2FtaG1UbGhPV21SR1l6UmphazVGVlZka01scFhWbk5SV0VKeVpXNU9kRnBIY0VsalZHaFdZekZzWmt4V2EzZFJWVGt5VFZaVk1tSXlNVE5WZVRGTFZFVXhlRkl3VWxkUmJtYzBWRWRzVGxwR1ZrdGpWbXh6VGtaR2ExVXdhekZhYkUwd1pVaHNSazVXWjNsV1IwWmFZekphZGxZeWFIUlBSRnB6VGpOQ1QxZEhSbkJpTUhoVVZEQmtNbVJ1WkZWT01scHRWbTA1ZFdJd1JURlpWa1p1WWxkS05tSXdNVU5hTW5nMlZHa3hTazU2YkhoWFYzQkpWR3Q0UkZZd1ZsbFVNMDVwVFZjd2VtUkhjM2xVVldONlRWVktjVlJIZEVsTlZXZzFZbXRLUW1WcmJGTlZNbmN6WkVWS1VsSkdPVWxOVldSeVpFUnNiRkpyYUhWWWVrSlhaVWhHYkUxclRUQmxWRTQwWVZVMVQxcEZjR3BWTWtwRlpGTXhXVmRJVGpOVE1uaFdWakp3WVZnelZYUlhiR2N3Wkc1T1NFMXFVWHBZTWxKSFRWaFNWMWt4V2taUk1sWndVMjVPZFZsWFRrZFZlazV3VlVkNGIyRlViRFZTUlZwNFlWaHNiRlJxYkcxYVJXeFlWRlpDTVZGV2JHOU9NRWwzVFc1S1YxSlVWalJrUkVKTFpHNW9ibUpHWkhoU1ZsWTFaV3BqTUZJeWVHbFplbVJJVm1reGVGcEVTbWxhTW5oRlpHeGtjVlJ1U2paTlZFWldVa1JXYW1WSVFsRmtSazVEVm10U1UyUklUbFJhU0doV1pHMDVXRTlWVWtOaFdFWXdUbTFrU0ZSdGIzUk5WMXBOWWxoU2VWSldUbkpoUldoSVZEQjBTVTB5Vmt4VWJGWjJWMVZHTmxKVE1ESmlhbEpaWWtSS2RGRlVWbkpoUlZKNFdtcGplRnB0Y0VSTlIwMDFVbXBrTTJRd05XMVZSWGQ1WVVaQ1psRXdXakZTYkVVelkwZG9SazVJU2taWk1XeFRUV3M1ZDJSWFJuaGlSekZyWWpCVk1tSXhXa0phUnpreVUyeG5lRlpXT1hOaU1EVldXa1V4UkZKNlFqQmpXR2hwVmpCVk1sZFlZM3BUVXpGNFVWY3hhMVJ1WkVKUlZHUnZXVlpGTkdOc1NUQmFWVWwwVW14YWNWZEVUbkpYYXpWTFkyMWFSazlIVm5kUmJXeHFVakIwYmxSRlpFWlZSM042WXpKT2Nsa3dTVE5sVmxaWlZFZGtjRTFZUWtkaU1IQXlaVlUxYUdSVlpGZFZibEpRWVZoYVFsWnRkSFpTYTBVelRGVTFTazFYYUZKUk1VcE1WMmt4U1dKNldreGpXRWt4Wkd0U1RXSnNPVmRVYTBaRlZtcEtabU13VWxGV1YzZ3dVVEowVEZSc2JESmFNMmd4WkZWT1NWa3piRVZPUlVwUlpWVXhNVlJFUW5wT01Wb3dXREkxTVdSclZtbFVNVTU0VGtSa1VrNXJWalZpTUVwUlRVWkdObVI2UmxKU1IyUnhZMVUxZVZnd05UQmpNRGt4V20xNFIyTlVWakJsUmtKR1QxZEdWbUZYZUZKVE1FWllZbGR3UWxWVmJITk9WbWd3WkVSWmRHRkZSbFZpTVd4bVVqRldjMUV5Y0cxV1ZrSlFWMGhrY0ZWUlBUMGFJQklhVldkNVJUSTJOVzFyVWtrMmNFOXVTMjFuYkRSQllVRkNRMUZJWkdnREtHTSUyNTNE").should eq("Egljb21tdW5pdHm4AQCqA-kOCsAOUVVSVFNsOXBNWEYxYlVablFXaGFiWFJNTW5WM1ZHSXdPVU5EWTNoeFJWWlVjRWRGVTBOa1prTktjVUoyWjBZemNEZHRPV2cwV1hWbVJtaFVPWFJwVjJaUU4xTXlNRWRaYlZwSVFUa3dlak5pTUV0dll6QkRVMlpsWHpoVFdUbHFSR0o1YkRkM1kydEhMVTVwWDFCdFdXOUhjR0Z6ZEMxbldVcEhUMjkzUm1saGRXSkViVmR6ZFhwd1QxTnpOME54TW5KUloxQlBkME5QU1VWVWMybHlNbFZvUVV0NlVIZFVhMVV5UzNWUmJHRldkRmszU1dKd1pVUllVMkZFVG1aV1ZsRnVUMGhsZFd0T01sVndTbGd3TkhweVdDMVBTRUphV25GNk5Yb3dYMWRCVTFnMlltODBPRmhIV205WlQwNW1YMjV1UlVKTWNucHNNSGR5Y1hKaFltUkVkblJYZG1Kc1FVaHFUV3BwTkc5R1pUQkVlbGw2ZHpSM2FISlBTSFJoYjJGbVMwNTBiV1pxV2pCSVNWWnZTalpRT0RoclVGVmhia1p5VFhsaWFTMVBjREZZV1dSTFdERkZjSHB0ZUhseWFtRXdNR1JmTkhOWmFEVlZTbVZ1ZUVkRU1XRlFhbU4xVERabk4wdDVSSGxHU2xsT1VEQlJXR1ZLTUhGM1UwWkJTSE5oWkRWQ2NXZHNaMFpqYW1ST1YxZFlhMDVOVUZSSFZWVktRekZSYVhodlUxTm1SV1EwTUdsdWNEWXlPV1YwUjNkcGFVcEVTM040YUZadmRXbHJhblkyZFdFelNHWXpUV3hMYURCa2JIRTFSblJ4Wms4NU1XbGtOM0pHYjBGeU4xZFJNMU5qYkZCd05rZE9jV1JqT1hGRGIyNU5Xak5TUlhkemFsUXRObGt4UWxkUE16ZGFaRTlxVGtaZlIweEhRbXRNWXpCWE9GUjNOMHBsYVhwS2RtSlZkMmxGTVhCbVNIWkdkVTFJY0MxbFdYSkVZM0V0ZFROWWRtVlFlV3hhYlVKMmVreGZUMGxOU2xaSlRFTlBZMVpEUjFwd1RHZFhZMmhIYVVKakxUSmFabXd0U1RNeFJEWkhlSGhYTkhOMU1GZGhOMjFCVlVnNGNFTlJXSGx2WW5ScWNUaHZXWGxKT1d0TVRXc3lRMWc0Um5wU2JEVjBlRGxpTW5vMVRYaEtkelExY201S1JHSmZkamhmTlhOWmRGYzRjak5FVVdkMlpXVnNRWEJyZW5OdFpHcEljVGhWYzFsZkxWa3dRVTkyTVZVMmIyMTNVeTFLVEUxeFIwUldRbmc0VEdsTlpGVktjVmxzTkZGa1UwazFabE0wZUhsRk5WZ3lWR0ZaYzJadlYyaHRPRFpzTjNCT1dHRnBiMHhUVDBkMmRuZFVOMlptVm05dWIwRTFZVkZuYldKNmIwMUNaMng2VGkxSk56bHhXV3BJVGt4RFYwVllUM05pTVcwemRHc3lUVWN6TVVKcVRHdElNVWg1YmtKQmVrbFNVMnczZEVKUlJGOUlNVWRyZERsbFJraHVYekJXZUhGbE1rTTBlVE40YVU1T1pFcGpVMkpFZFMxWVdITjNTMnhWVjJwYVgzVXRXbGcwZG5OSE1qUXpYMlJHTVhSV1kxWkZRMlZwU25OdVlXTkdVek5wVUd4b2FUbDVSRVp4YVhsbFRqbG1aRWxYVFZCMVFWbG9OMEl3TW5KV1JUVjRkREJLZG5obmJGZHhSVlY1ZWpjMFIyeGlZemRIVmkxeFpESmlaMnhFZGxkcVRuSjZNVEZWUkRWamVIQlFkRk5DVmtSU2RITlRaSGhWZG05WE9VUkNhWEYwTm1kSFRtb3RNV1pNYlhSeVJWTnJhRWhIVDB0SU0yVkxUbFZ2V1VGNlJTMDJialJZYkRKdFFUVnJhRVJ4WmpjeFptcERNR001UmpkM2QwNW1VRXd5YUZCZlEwWjFSbEUzY0doRk5ISkZZMWxTTWs5d2RXRnhiRzFrYjBVMmIxWkJaRzkyU2xneFZWOXNiMDVWWkUxRFJ6QjBjWGhpVjBVMldYY3pTUzF4UVcxa1RuZEJRVGRvWVZFNGNsSTBaVUl0UmxacVdETnJXazVLY21aRk9HVndRbWxqUjB0blRFZEZVR3N6YzJOclkwSTNlVlZZVEdkcE1YQkdiMHAyZVU1aGRVZFdVblJQYVhaQlZtdHZSa0UzTFU1Sk1XaFJRMUpMV2kxSWJ6WkxjWEkxZGtSTWJsOVdUa0ZFVmpKZmMwUlFWV3gwUTJ0TFRsbDJaM2gxZFVOSVkzbEVORUpRZVUxMVREQnpOMVowWDI1MWRrVmlUMU54TkRkUk5rVjViMEpRTUZGNmR6RlJSR2RxY1U1eVgwNTBjMDkxWm14R2NUVjBlRkJGT1dGVmFXeFJTMEZYYldwQlVVbHNOVmgwZERZdGFFRlViMWxmUjFWc1EycG1WVkJQV0hkcFVRPT0aIhIcVWd5RTI2NW1rUkk2cE9uS21nbDRBYUFCQ1E9PUhkaAMoYw==")
    end
  end

  describe "#extract_plid" do
    it "correctly extracts playlist ID from trending URL" do
      extract_plid("/feed/trending?bp=4gIuCggvbS8wNHJsZhIiUExGZ3F1TG5MNTlhbVBud2pLbmNhZUp3MDYzZlU1M3Q0cA%3D%3D").should eq("PLFgquLnL59amPnwjKncaeJw063fU53t4p")
      extract_plid("/feed/trending?bp=4gIvCgkvbS8wYnp2bTISIlBMaUN2Vkp6QnVwS2tDaFNnUDdGWFhDclo2aEp4NmtlTm0%3D").should eq("PLiCvVJzBupKkChSgP7FXXCrZ6hJx6keNm")
      extract_plid("/feed/trending?bp=4gIuCggvbS8wNWpoZxIiUEwzWlE1Q3BOdWxRbUtPUDNJekdsYWN0V1c4dklYX0hFUA%3D%3D").should eq("PL3ZQ5CpNulQmKOP3IzGlactWW8vIX_HEP")
      extract_plid("/feed/trending?bp=4gIuCggvbS8wMnZ4bhIiUEx6akZiYUZ6c21NUnFhdEJnVTdPeGNGTkZhQ2hqTkVERA%3D%3D").should eq("PLzjFbaFzsmMRqatBgU7OxcFNFaChjNEDD")
    end
  end

  describe "#sign_token" do
    it "correctly signs a given hash" do
      token = {
        "session" => "v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "expires" => 1554680038,
        "scopes"  => [
          ":notifications",
          ":subscriptions/*",
          "GET:tokens*",
        ],
        "signature" => "f__2hS20th8pALF305PJFK-D2aVtvefNnQheILHD2vU=",
      }
      sign_token("SECRET_KEY", token).should eq(token["signature"])

      token = {
        "session"   => "v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "scopes"    => [":notifications", "POST:subscriptions/*"],
        "signature" => "fNvXoT0MRAL9eE6lTE33CEg8HitYJDOL9a22rSN2Ihg=",
      }
      sign_token("SECRET_KEY", token).should eq(token["signature"])
    end
  end
end
