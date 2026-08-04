import SwiftUI

/// 개인정보처리방침 — 네이티브 정적 화면. 원문: clipnote.co.kr/privacy (동일 내용).
/// 방침은 거의 바뀌지 않아 앱 내장. 추후 백엔드 API 제공 시 데이터 소스만 교체 가능.
///
/// **본문은 번역하지 않는다.** 법적 효력을 갖는 문서라 기계 번역본을 게시하면 어느 쪽이
/// 구속력을 갖는지가 불분명해진다(웹 `/{en,ja,zh}/privacy` 도 같은 결정이다). 대신 한국어가
/// 아닌 표시 언어에서는 본문 위에 `language.koreanOnlyNotice` 안내를 붙이고, 제목·내비게이션
/// 라벨만 번역한다.
struct PrivacyView: View {
    @Environment(LocalizationStore.self) private var i18n

    private struct Section: Identifiable {
        let heading: String
        let body: [String]
        var id: String { heading }
    }

    private let effectiveDate = "시행일: 2026년 8월 4일"
    private let intro = "ClipNote(이하 \"서비스\")는 「개인정보 보호법」을 준수하며, 이용자의 개인정보를 보호하기 위해 다음과 같이 개인정보처리방침을 두고 있습니다. 서비스는 회원 로그인에 필요한 최소한의 정보만 수집합니다."

    private let sections: [Section] = [
        Section(heading: "1. 수집하는 개인정보 항목", body: [
            "서비스는 Google·카카오 소셜 로그인을 통해 회원 식별에 필요한 정보를 수집합니다. 서비스의 자체 데이터베이스에는 회원 구분용 고유 식별자만 저장하며, 이메일·프로필 정보는 인증 처리(Supabase)에 보관됩니다.",
            "· 필수: 소셜 계정 고유 식별자(고유 ID), 이메일",
            "· 선택: 프로필 닉네임, 프로필 이미지(공급자가 제공하는 경우)",
            "· 자동 생성: 서비스 이용 과정에서 만들어지는 클립 정보(저장한 URL, 제목, 태그 등)와 로그인 유지를 위한 세션 정보",
            "· 광고 게재 과정에서 자동 수집: 기기·브라우저 정보, IP 주소, 광고 조회·클릭 기록",
            "비로그인 상태로 이용하는 경우, 저장한 클립과 태그는 서버로 전송되지 않고 이용자의 기기 내 저장소에만 보관됩니다.",
            "서비스는 무료로 제공하기 위해 광고를 게재합니다(모바일 앱 Google AdMob, 웹 Google AdSense). 광고 모듈이 동작하는 시점부터 Google LLC가 위 광고 관련 정보를 자동으로 수집하며, 실제 광고가 표시되지 않더라도 수집이 일어날 수 있습니다. 서비스는 이 정보를 자체 서버에 저장하지 않습니다. 모바일 앱은 이용자 추적 권한(App Tracking Transparency)을 요청하지 않으므로 광고 식별자(IDFA)는 수집하지 않습니다.",
        ]),
        Section(heading: "2. 개인정보의 수집·이용 목적", body: [
            "· 회원 식별 및 로그인 상태 유지",
            "· 이용자가 만든 클립(공유 링크·내 클립)의 저장·조회·관리",
            "· 서비스 운영 및 문의 대응",
            "· 무료 서비스 운영을 위한 광고 게재 및 성과 측정",
        ]),
        Section(heading: "3. 보유 및 이용 기간", body: [
            "수집한 개인정보는 회원 탈퇴 시까지 보유합니다. 이용자는 서비스 내 설정 화면의 회원 탈퇴 기능으로 직접 탈퇴할 수 있으며, 탈퇴 시 저장한 모든 클립과 계정 정보가 즉시 영구 삭제되어 복구할 수 없습니다. 다만 관계 법령에 따라 보존이 필요한 경우 해당 기간 동안 보관합니다.",
        ]),
        Section(heading: "4. 개인정보 처리위탁", body: [
            "서비스는 안정적인 운영을 위해 개인정보 처리 업무를 위탁하고 있습니다. 이용자의 데이터는 국내(대한민국) 리전 서버에 저장됩니다. 다만 소셜 로그인 인증 과정에서 일부 정보가 각 공급자의 서버(국외 포함)에서 처리될 수 있습니다.",
            "· Supabase, Inc. — 데이터베이스 저장, 사용자 인증(로그인) 처리 / 대한민국(서울 리전)",
            "· Google LLC — 광고 게재 및 성과 측정(AdSense·AdMob) / 국외(미국 등)",
            "소셜 로그인 과정에서 Google LLC, ㈜카카오가 각 사의 정책에 따라 인증을 처리합니다. 각 공급자의 개인정보 처리 기준은 해당 공급자의 방침을 따릅니다.",
        ]),
        Section(heading: "5. 개인정보의 제3자 제공", body: [
            "서비스는 이용자의 개인정보를 외부에 판매하지 않으며, 법령에 따라 요구되는 경우를 제외하고 제3자에게 제공하지 않습니다. 다만 광고 게재를 위해 위 4항의 광고 사업자에게 기기·브라우저 정보와 IP 주소가 전달됩니다. 이용자는 Google 광고 설정(adssettings.google.com)에서 맞춤 광고를 제한할 수 있습니다.",
        ]),
        Section(heading: "6. 이용자의 권리와 행사 방법", body: [
            "이용자는 언제든지 자신의 개인정보에 대해 열람·정정·삭제·처리정지를 요청할 수 있습니다. 요청은 아래 연락처로 문의해 주시면 지체 없이 조치합니다. 서비스 내 로그아웃·클립 삭제 기능으로 직접 처리할 수 있으며, 설정 화면의 회원 탈퇴 기능으로 계정과 저장한 모든 데이터를 직접 영구 삭제할 수 있습니다.",
        ]),
        Section(heading: "7. 개인정보의 파기", body: [
            "보유 기간이 지나거나 처리 목적이 달성된 개인정보는 지체 없이 파기합니다. 전자적 파일은 복구할 수 없는 방법으로 영구 삭제합니다.",
        ]),
        Section(heading: "8. 세션 정보 및 로컬 저장소", body: [
            "서비스는 로그인 상태 유지를 위해 세션 정보를 이용자의 기기 내 저장소(앱은 로컬 저장소)에 보관합니다. 이 정보는 로그아웃하거나 앱을 삭제할 때 제거됩니다.",
        ]),
        Section(heading: "9. 개인정보 보호책임자", body: [
            "개인정보 처리에 관한 문의·불만·피해 구제는 아래로 연락해 주세요.",
            "· 책임자: pikaworks 운영자",
            "· 이메일: pikaworks.help@gmail.com",
        ]),
        Section(heading: "10. 방침의 변경", body: [
            "이 개인정보처리방침은 시행일부터 적용되며, 내용이 변경되는 경우 변경 사항을 서비스 화면에 공지합니다.",
        ]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(i18n.t("common.privacy"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.fg)
                if i18n.language != .korean {
                    Text(i18n.t("language.koreanOnlyNotice"))
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.fgMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(AppColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        .padding(.top, 10)
                }
                Text(effectiveDate)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.fgMuted)
                    .padding(.top, 4)
                Text(intro)
                    .font(.system(size: 14)).lineSpacing(4)
                    .foregroundStyle(AppColor.fgMuted)
                    .padding(.top, 12)

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.heading)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.fg)
                        ForEach(section.body, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 14)).lineSpacing(4)
                                .foregroundStyle(AppColor.fgMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 22)
                }

                Text(verbatim: "© 2026 PIKAWORKS")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColor.fgMuted)
                    .padding(.top, 28)
            }
            .padding(20)
        }
        .background(AppColor.bg)
        .navigationTitle(i18n.t("common.privacy"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
