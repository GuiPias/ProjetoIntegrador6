package br.com.projetointegrador.produtos;

import jakarta.validation.Valid;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.server.ResponseStatusException;

@Controller
public class ProdutoController {

    private final ProdutoRepository repository;

    public ProdutoController(ProdutoRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/")
    public String listar(Model model) {
        model.addAttribute("produtos", repository.findAll(Sort.by("nome")));
        return "lista";
    }

    @GetMapping("/produtos/novo")
    public String novo(Model model) {
        model.addAttribute("produto", new Produto());
        return "formulario";
    }

    @GetMapping("/produtos/{id}/editar")
    public String editar(@PathVariable Long id, Model model) {
        model.addAttribute("produto", buscar(id));
        return "formulario";
    }

    @PostMapping("/produtos")
    public String criar(@Valid @ModelAttribute("produto") Produto produto, BindingResult result) {
        if (result.hasErrors()) {
            return "formulario";
        }
        produto.setId(null);
        repository.save(produto);
        return "redirect:/";
    }

    @PostMapping("/produtos/{id}")
    public String atualizar(@PathVariable Long id, @Valid @ModelAttribute("produto") Produto produto,
                            BindingResult result) {
        buscar(id);
        if (result.hasErrors()) {
            produto.setId(id);
            return "formulario";
        }
        produto.setId(id);
        repository.save(produto);
        return "redirect:/";
    }

    @PostMapping("/produtos/{id}/excluir")
    public String excluir(@PathVariable Long id) {
        repository.delete(buscar(id));
        return "redirect:/";
    }

    private Produto buscar(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Produto não encontrado"));
    }
}
