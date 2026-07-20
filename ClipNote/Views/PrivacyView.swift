import SwiftUI

/// 개인정보처리방침 — 네이티브 정적 화면. 원문: clipnote.co.kr/privacy (동일 내용).
/// 방침은 거의 바뀌지 않아 앱 내장. 추후 백엔드 API 제공 시 데이터 소스만 교체 가능.
struct PrivacyView: View {
    private struct Section: Identifiable {
        let heading: String
        let body: [String]
        var id: String { heading }
    }

    private let effectiveDate = "시행일: 2026년 7월 10일"
    private let intro = "ClipNote(이하 \"서비스\")는 「개인정보 보호법」을 준수하며, 이용자의 개인정보를 보호하기 위해 다음과 같이 개인정보처리방침을 두고 있습니다. 서비스는 회원 로그인에 필요한 최소한의 정보만 수집합니다."

    private let sections: [Section] = [
        Section(heading: "1. 수집하는 개인정보 항목", body: [
            "서비스는 Google·카카오 소셜 로그인을 통해 회원 식별에 필요한 정보를 수집합니다. 서비스의 자체 데이터베이스에는 회원 구분용 고유 식별자만 저장하며, 이메일·프로필 정보는 인증 처리(Supabase)에 보관됩니다.",
            "· 필수: 소셜 계정 고유 식별자(고유 ID), 이메일",
            "· 선택: 프로필 닉네임, 프로필 이미지(공급자가 제공하는 경우)",
            "· 자동 생성: 서비스 이용 과정에서 만들어지는 클립 정보(저장한 URL, 제목, 태그 등)와 로그인 유지를 위한 세션 정보",
            "비로그인 상태로 이용하는 경우, 저장한 클립과 태그는 서버로 전송되지 않고 이용자의 기기 내 저장소에만 보관됩니다.",
        ]),
        Section(heading: "2. 개인정보의 수집·이용 목적", body: [
            "· 회원 식별 및 로그인 상태 유지",
            "· 이용자가 만든 클립(공유 링크·내 클립)의 저장·조회·관리",
            "· 서비스 운영 및 문의 대응",
        ]),
        Section(heading: "3. 보유 및 이용 기간", body: [
            "수집한 개인정보는 회원 탈퇴 시까지 보유합니다. 이용자는 서비스 내 설정 화면의 회원 탈퇴 기능으로 직접 탈퇴할 수 있으며, 탈퇴 시 저장한 모든 클립과 계정 정보가 즉시 영구 삭제되어 복구할 수 없습니다. 다만 관계 법령에 따라 보존이 필요한 경우 해당 기간 동안 보관합니다.",
        ]),
        Section(heading: "4. 개인정보 처리위탁", body: [
            "서비스는 안정적인 운영을 위해 개인정보 처리 업무를 위탁하고 있습니다. 이용자의 데이터는 국내(대한민국) 리전 서버에 저장됩니다. 다만 소셜 로그인 인증 과정에서 일부 정보가 각 공급자의 서버(국외 포함)에서 처리될 수 있습니다.",
            "· Supabase, Inc. — 데이터베이스 저장, 사용자 인증(로그인) 처리 / 대한민국(서울 리전)",
            "소셜 로그인 과정에서 Google LLC, ㈜카카오가 각 사의 정책에 따라 인증을 처리합니다. 각 공급자의 개인정보 처리 기준은 해당 공급자의 방침을 따릅니다.",
        ]),
        Section(heading: "5. 개인정보의 제3자 제공", body: [
            "서비스는 이용자의 개인정보를 외부에 판매하거나 제3자에게 제공하지 않습니다. 다만 법령에 따라 요구되는 경우는 예외로 합니다.",
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
                Text("개인정보처리방침")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.fg)
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

                Text("© 2026 PIKAWORKS")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColor.fgMuted)
                    .padding(.top, 28)
            }
            .padding(20)
        }
        .background(AppColor.bg)
        .navigationTitle("개인정보처리방침")
        .navigationBarTitleDisplayMode(.inline)
    }
}
