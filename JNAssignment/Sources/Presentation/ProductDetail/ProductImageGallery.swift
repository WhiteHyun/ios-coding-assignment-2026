import SwiftUI

struct ProductImageGallery: View {
  let images: [URL]

  var body: some View {
    Group {
      if images.isEmpty {
        ProductImage(url: nil)
          .accessibilityLabel("상품 이미지 없음")
      } else {
        TabView {
          ForEach(Array(images.enumerated()), id: \.offset) { index, url in
            ProductImage(url: url)
              .padding(24)
              .accessibilityLabel("상품 이미지 \(index + 1), 총 \(images.count)장")
          }
        }
        .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
      }
    }
    .frame(height: 300)
    .frame(maxWidth: .infinity)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
  }
}
